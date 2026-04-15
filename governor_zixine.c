// SPDX-License-Identifier: GPL-2.0
/*
 * Zixine Velocity v1.0 - The Smart Hybrid
 * Full Implementation: Velocity Tracking, I/O Boost, & Adaptive Sampling
 * Author: zixine
 */

#include <linux/cpufreq.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/sched/clock.h>
#include <linux/workqueue.h>

/* Zixine Velocity Heuristic Parameters */
static unsigned int target_load_big = 65;    /* Sangat agresif untuk core besar */
static unsigned int target_load_little = 75; /* Agresif untuk core kecil */
static unsigned int fast_ramp_up_load = 85;  /* Ambang batas tancap gas */

struct zv_cpu_info {
    u64 prev_cpu_idle;
    u64 prev_cpu_wall;
    unsigned int prev_load;          
    unsigned int target_freq;
    unsigned int hold_counter;       
    unsigned int next_delay_ms;
};

static DEFINE_PER_CPU(struct zv_cpu_info, zv_info);

struct zv_policy_info {
    struct delayed_work work;
    struct cpufreq_policy *policy;
};

/* ========================================================================
 * CORE LOGIC: VELOCITY-BASED SCALING WITH FULL OPTIMIZATIONS
 * ======================================================================== */
static void zv_eval_freq(struct cpufreq_policy *policy)
{
    struct zv_cpu_info *info = &per_cpu(zv_info, policy->cpu);
    u64 now, idle_time, delta_wall, delta_idle;
    unsigned int load, freq_target, current_freq = policy->cur;
    unsigned int load_velocity;

    now = local_clock();
    /* Optimasi 1: Include I/O Wait (Parameter ke-3 = 1) */
    idle_time = get_cpu_idle_time(policy->cpu, &delta_wall, 1);

    if (info->prev_cpu_wall == 0) {
        info->prev_cpu_wall = now;
        info->prev_cpu_idle = idle_time;
        info->next_delay_ms = 20;
        return;
    }

    delta_wall = now - info->prev_cpu_wall;
    delta_idle = idle_time - info->prev_cpu_idle;
    info->prev_cpu_wall = now;
    info->prev_cpu_idle = idle_time;

    if (delta_wall == 0 || delta_idle > delta_wall)
        load = 0;
    else
        load = div64_u64(100 * (delta_wall - delta_idle), delta_wall);

    /* Optimasi 2: Hitung Velocity (Akselerasi Beban) */
    load_velocity = (load > info->prev_load) ? (load - info->prev_load) : 0;
    info->prev_load = load;

    bool is_big = (policy->cpuinfo.max_freq > (policy->cpuinfo.min_freq * 2));
    unsigned int dyn_target_load = is_big ? target_load_big : target_load_little;

    /* Optimasi 3: Decision Matrix Berbasis Velocity */
    if (load >= fast_ramp_up_load || load_velocity > 40) {
        /* INSTANT SPIKE */
        freq_target = policy->max;
        
        /* VELOCITY HOLD: Durasi tahan frekuensi tergantung kegalakan beban */
        if (load_velocity > 55)
            info->hold_counter = 12; /* Sangat agresif */
        else if (info->hold_counter < 6)
            info->hold_counter = 6;  /* Standar agresif */
            
    } else if (load > dyn_target_load) {
        /* Scaling Normal jika beban stabil di atas target */
        freq_target = (policy->max * load) / 100;
        if (freq_target < current_freq) freq_target = current_freq;
        
    } else {
        /* RAPID FALL LOGIC */
        if (info->hold_counter > 0) {
            freq_target = current_freq;
            info->hold_counter--;
        } else {
            /* Penurunan 10% (Smooth Decay) */
            unsigned int decay_step = current_freq / 10;
            freq_target = (current_freq > policy->min + decay_step) ? 
                          current_freq - decay_step : policy->min;
        }
    }

    /* Terapkan ke Driver */
    if (freq_target != info->target_freq) {
        info->target_freq = freq_target;
        __cpufreq_driver_target(policy, freq_target, CPUFREQ_RELATION_L);
    }

    /* Optimasi 4: Adaptive Sampling (10ms saat sibuk, 40ms saat santai) */
    if (load > 20 || info->hold_counter > 0)
        info->next_delay_ms = 10;
    else
        info->next_delay_ms = 40; 
}

/* --- BOILERPLATE INTEGRASI KERNEL (LENGKAP) --- */

static void zv_work_handler(struct work_struct *work)
{
    struct zv_policy_info *zpinfo = container_of(work, struct zv_policy_info, work.work);
    zv_eval_freq(zpinfo->policy);
    schedule_delayed_work_on(zpinfo->policy->cpu, &zpinfo->work, 
                             msecs_to_jiffies(per_cpu(zv_info, zpinfo->policy->cpu).next_delay_ms));
}

static int zv_init(struct cpufreq_policy *policy)
{
    struct zv_policy_info *zpinfo = kzalloc(sizeof(*zpinfo), GFP_KERNEL);
    if (!zpinfo) return -ENOMEM;
    zpinfo->policy = policy;
    INIT_DEFERRABLE_WORK(&zpinfo->work, zv_work_handler);
    policy->governor_data = zpinfo;
    return 0;
}

static void zv_exit(struct cpufreq_policy *policy)
{
    struct zv_policy_info *zpinfo = policy->governor_data;
    if (zpinfo) {
        cancel_delayed_work_sync(&zpinfo->work);
        kfree(zpinfo);
        policy->governor_data = NULL;
    }
}

static int zv_start(struct cpufreq_policy *policy)
{
    unsigned int cpu;
    for_each_cpu(cpu, policy->cpus) {
        struct zv_cpu_info *info = &per_cpu(zv_info, cpu);
        info->prev_cpu_wall = 0;
        info->hold_counter = 0;
        info->prev_load = 0;
        info->next_delay_ms = 20;
    }
    schedule_delayed_work_on(policy->cpu, &((struct zv_policy_info *)policy->governor_data)->work, msecs_to_jiffies(20));
    return 0;
}

static void zv_stop(struct cpufreq_policy *policy)
{
    struct zv_policy_info *zpinfo = policy->governor_data;
    if (zpinfo) cancel_delayed_work_sync(&zpinfo->work);
}

static struct cpufreq_governor gov_zixine_velocity = {
    .name		= "zixine_velocity",
    .owner		= THIS_MODULE,
    .init		= zv_init,
    .exit		= zv_exit,
    .start		= zv_start,
    .stop		= zv_stop,
};

static int __init zv_module_init(void) { return cpufreq_register_governor(&gov_zixine_velocity); }
static void __exit zv_module_exit(void) { cpufreq_unregister_governor(&gov_zixine_velocity); }

module_init(zv_module_init);
module_exit(zv_module_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Zixine Velocity: High-Velocity Adaptive Scaling with I/O Boost");
