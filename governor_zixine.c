// SPDX-License-Identifier: GPL-2.0
/*
 * Zixine Unified Governor Suite v1.0
 * Includes: Velocity (Hybrid), Overdrive (Performance), EcoPulse (Battery)
 * Optimized for GKI 5.10 / 6.1 / 6.6
 * Author: Partner Coding & Zixine Project
 */

#include <linux/cpufreq.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/sched/clock.h>
#include <linux/workqueue.h>

/* --- DATA STRUCTURES --- */
struct zixine_info {
    u64 prev_idle;
    u64 prev_wall;
    unsigned int prev_load;
    unsigned int hold_counter;
    unsigned int target_freq;
    unsigned int next_delay_ms;
};

static DEFINE_PER_CPU(struct zixine_info, cpu_zinfo);

struct zixine_policy {
    struct delayed_work work;
    struct cpufreq_policy *policy;
};

/* ========================================================================
 * LOGIKA 1: ZIXINE VELOCITY (THE SMART HYBRID)
 * ======================================================================== */
static void zixine_velocity_eval(struct cpufreq_policy *policy) {
    struct zixine_info *info = &per_cpu(cpu_zinfo, policy->cpu);
    u64 now, idle_time, delta_wall, delta_idle;
    unsigned int load, velocity, freq_target;

    now = local_clock();
    idle_time = get_cpu_idle_time(policy->cpu, &delta_wall, 1);

    delta_wall = now - info->prev_wall;
    delta_idle = idle_time - info->prev_idle;
    
    if (delta_wall == 0 || delta_idle > delta_wall) load = 0;
    else load = div64_u64(100 * (delta_wall - delta_idle), delta_wall);

    /* Logika Velocity Tracking */
    velocity = (load > info->prev_load) ? (load - info->prev_load) : 0;
    info->prev_load = load;
    info->prev_wall = now;
    info->prev_idle = idle_time;

    /* Decision Matrix: Velocity Awareness */
    if (velocity > 40 || load > 85) {
        freq_target = policy->max;
        info->hold_counter = (velocity > 55) ? 12 : 6;
    } else if (load > 65) {
        freq_target = (policy->max * load) / 100;
    } else {
        if (info->hold_counter > 0) {
            freq_target = policy->cur;
            info->hold_counter--;
        } else {
            freq_target = policy->min;
        }
    }

    if (freq_target != info->target_freq) {
        info->target_freq = freq_target;
        __cpufreq_driver_target(policy, freq_target, CPUFREQ_RELATION_L);
    }
    info->next_delay_ms = (load > 20 || info->hold_counter > 0) ? 10 : 40;
}

/* ========================================================================
 * LOGIKA 2: ZIXINE OVERDRIVE (THE PERFORMANCE BEAST)
 * ======================================================================== */
static void zixine_overdrive_eval(struct cpufreq_policy *policy) {
    struct zixine_info *info = &per_cpu(cpu_zinfo, policy->cpu);
    u64 now, idle_time, delta_wall, delta_idle;
    unsigned int load, freq_target;
    unsigned int floor = (policy->max * 60) / 100;

    now = local_clock();
    idle_time = get_cpu_idle_time(policy->cpu, &delta_wall, 1);
    delta_wall = now - info->prev_wall;
    delta_idle = idle_time - info->prev_idle;
    load = (delta_wall > 0) ? div64_u64(100 * (delta_wall - delta_idle), delta_wall) : 0;
    info->prev_wall = now; info->prev_idle = idle_time;

    if (load > 40) {
        freq_target = policy->max;
        info->hold_counter = 25;
    } else if (info->hold_counter > 0) {
        freq_target = policy->max;
        info->hold_counter--;
    } else {
        freq_target = floor;
    }

    if (freq_target != info->target_freq) {
        info->target_freq = freq_target;
        __cpufreq_driver_target(policy, freq_target, CPUFREQ_RELATION_L);
    }
    info->next_delay_ms = 10;
}

/* ========================================================================
 * LOGIKA 3: ZIXINE ECOPULSE (THE BATTERY SAVER)
 * ======================================================================== */
static void zixine_ecopulse_eval(struct cpufreq_policy *policy) {
    struct zixine_info *info = &per_cpu(cpu_zinfo, policy->cpu);
    u64 now, idle_time, delta_wall, delta_idle;
    unsigned int load, freq_target;

    now = local_clock();
    idle_time = get_cpu_idle_time(policy->cpu, &delta_wall, 1);
    delta_wall = now - info->prev_wall;
    delta_idle = idle_time - info->prev_idle;
    load = (delta_wall > 0) ? div64_u64(100 * (delta_wall - delta_idle), delta_wall) : 0;
    info->prev_wall = now; info->prev_idle = idle_time;

    if (load > 90) freq_target = policy->max;
    else freq_target = policy->min;

    if (freq_target != info->target_freq) {
        info->target_freq = freq_target;
        __cpufreq_driver_target(policy, freq_target, CPUFREQ_RELATION_L);
    }
    info->next_delay_ms = 40;
}

/* --- WORKER HANDLERS --- */
static void zv_work(struct work_struct *work) {
    struct zixine_policy *zp = container_of(work, struct zixine_policy, work.work);
    zixine_velocity_eval(zp->policy);
    schedule_delayed_work_on(zp->policy->cpu, &zp->work, msecs_to_jiffies(per_cpu(cpu_zinfo, zp->policy->cpu).next_delay_ms));
}

static void zo_work(struct work_struct *work) {
    struct zixine_policy *zp = container_of(work, struct zixine_policy, work.work);
    zixine_overdrive_eval(zp->policy);
    schedule_delayed_work_on(zp->policy->cpu, &zp->work, msecs_to_jiffies(10));
}

static void ze_work(struct work_struct *work) {
    struct zixine_policy *zp = container_of(work, struct zixine_policy, work.work);
    zixine_ecopulse_eval(zp->policy);
    schedule_delayed_work_on(zp->policy->cpu, &zp->work, msecs_to_jiffies(40));
}

/* --- COMMON LIFECYCLE --- */
static int z_init_common(struct cpufreq_policy *p, void (*func)(struct work_struct *)) {
    struct zixine_policy *zp = kzalloc(sizeof(*zp), GFP_KERNEL);
    if (!zp) return -ENOMEM;
    zp->policy = p;
    INIT_DEFERRABLE_WORK(&zp->work, func);
    p->governor_data = zp;
    return 0;
}

static void z_exit_common(struct cpufreq_policy *p) {
    struct zixine_policy *zp = p->governor_data;
    if (zp) { cancel_delayed_work_sync(&zp->work); kfree(zp); p->governor_data = NULL; }
}

static int z_start(struct cpufreq_policy *p) {
    struct zixine_policy *zp = p->governor_data;
    schedule_delayed_work_on(p->cpu, &zp->work, msecs_to_jiffies(20));
    return 0;
}

/* --- GOVERNOR DEFINITIONS --- */
static int zv_i(struct cpufreq_policy *p) { return z_init_common(p, zv_work); }
static struct cpufreq_governor g_vel = { .name="zixine_velocity", .init=zv_i, .exit=z_exit_common, .start=z_start, .stop=z_exit_common, .owner=THIS_MODULE };

static int zo_i(struct cpufreq_policy *p) { return z_init_common(p, zo_work); }
static struct cpufreq_governor g_ovd = { .name="zixine_overdrive", .init=zo_i, .exit=z_exit_common, .start=z_start, .stop=z_exit_common, .owner=THIS_MODULE };

static int ze_i(struct cpufreq_policy *p) { return z_init_common(p, ze_work); }
static struct cpufreq_governor g_eco = { .name="zixine_ecopulse", .init=ze_i, .exit=z_exit_common, .start=z_start, .stop=z_exit_common, .owner=THIS_MODULE };

/* --- MODULE REGISTER --- */
static int __init z_mod_init(void) {
    cpufreq_register_governor(&g_vel);
    cpufreq_register_governor(&g_ovd);
    cpufreq_register_governor(&g_eco);
    return 0;
}

static void __exit z_mod_exit(void) {
    cpufreq_unregister_governor(&g_vel);
    cpufreq_unregister_governor(&g_ovd);
    cpufreq_unregister_governor(&g_eco);
}

module_init(z_mod_init);
module_exit(z_mod_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Zixine Suite: Velocity, Overdrive, EcoPulse");
