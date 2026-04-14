// SPDX-License-Identifier: GPL-2.0
/*
 * Zixine Unified Governor (Velocity, Overdrive, EcoPulse)
 * Designed for GKI 5.10+
 * Author: zixine
 */

#include <linux/cpufreq.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/sched/clock.h>
#include <linux/workqueue.h>

struct zixine_info {
    u64 prev_idle;
    u64 prev_wall;
    unsigned int prev_load;
    unsigned int hold_counter;
    unsigned int target_freq;
};

static DEFINE_PER_CPU(struct zixine_info, cpu_zinfo);

struct zixine_policy {
    struct delayed_work work;
    struct cpufreq_policy *policy;
    int type;
};

static void zixine_eval(struct cpufreq_policy *policy) {
    struct zixine_policy *zp = policy->governor_data;
    struct zixine_info *info = &per_cpu(cpu_zinfo, policy->cpu);
    u64 now, idle_time, delta_wall, delta_idle;
    unsigned int load, freq_target;
    unsigned int velocity;

    now = local_clock();
    idle_time = get_cpu_idle_time(policy->cpu, &delta_wall, 1);

    delta_wall = now - info->prev_wall;
    delta_idle = idle_time - info->prev_idle;
    
    if (delta_wall == 0 || delta_idle > delta_wall) load = 0;
    else load = div64_u64(100 * (delta_wall - delta_idle), delta_wall);

    velocity = (load > info->prev_load) ? (load - info->prev_load) : 0;
    info->prev_load = load;
    info->prev_wall = now;
    info->prev_idle = idle_time;

    switch (zp->type) {
        case 1:
            {
                unsigned int floor = (policy->max * 60) / 100;
                if (load > 40) {
                    freq_target = policy->max;
                    info->hold_counter = 25;
                } else if (info->hold_counter > 0) {
                    freq_target = policy->max;
                    info->hold_counter--;
                } else {
                    freq_target = floor;
                }
                if (freq_target < floor) freq_target = floor;
            }
            break;

        case 2: /* ECOPULSE MODE (Battery) */
            if (load > 90) freq_target = policy->max;
            else freq_target = policy->min;
            break;

        default: /* VELOCITY MODE (Hybrid - Standard) */
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
            break;
    }

    if (freq_target != info->target_freq) {
        info->target_freq = freq_target;
        __cpufreq_driver_target(policy, freq_target, CPUFREQ_RELATION_L);
    }
}

/* --- WORKER HANDLER --- */
static void zixine_work_handler(struct work_struct *work) {
    struct zixine_policy *zp = container_of(work, struct zixine_policy, work.work);
    zixine_eval(zp->policy);
    
    /* Dynamic Sampling Rate */
    int delay = 20;
    if (zp->type == 1) delay = 10;
    else if (zp->type == 2) delay = 40;

    schedule_delayed_work_on(zp->policy->cpu, &zp->work, msecs_to_jiffies(delay));
}

/* --- LIFECYCLE FUNCTIONS --- */
static int zixine_init_common(struct cpufreq_policy *policy, int type) {
    struct zixine_policy *zp = kzalloc(sizeof(*zp), GFP_KERNEL);
    if (!zp) return -ENOMEM;
    zp->policy = policy;
    zp->type = type;
    INIT_DEFERRABLE_WORK(&zp->work, zixine_work_handler);
    policy->governor_data = zp;
    return 0;
}

static void zixine_exit_common(struct cpufreq_policy *policy) {
    struct zixine_policy *zp = policy->governor_data;
    if (zp) {
        cancel_delayed_work_sync(&zp->work);
        kfree(zp);
        policy->governor_data = NULL;
    }
}

static int zixine_start(struct cpufreq_policy *policy) {
    struct zixine_policy *zp = policy->governor_data;
    schedule_delayed_work_on(policy->cpu, &zp->work, msecs_to_jiffies(20));
    return 0;
}

static void zixine_stop(struct cpufreq_policy *policy) {
    struct zixine_policy *zp = policy->governor_data;
    cancel_delayed_work_sync(&zp->work);
}

/* --- REGISTERING 3 GOVERNORS --- */

#VELOCITY
static int z_vel_init(struct cpufreq_policy *p) { return zixine_init_common(p, 0); }
static struct cpufreq_governor gov_velocity = {
    .name = "zixine_velocity", .init = z_vel_init, .exit = zixine_exit_common,
    .start = zixine_start, .stop = zixine_stop, .owner = THIS_MODULE,
};

#OVERDRIVE
static int z_ovd_init(struct cpufreq_policy *p) { return zixine_init_common(p, 1); }
static struct cpufreq_governor gov_overdrive = {
    .name = "zixine_overdrive", .init = z_ovd_init, .exit = zixine_exit_common,
    .start = zixine_start, .stop = zixine_stop, .owner = THIS_MODULE,
};

#ECOPULSE
static int z_eco_init(struct cpufreq_policy *p) { return zixine_init_common(p, 2); }
static struct cpufreq_governor gov_ecopulse = {
    .name = "zixine_ecopulse", .init = z_eco_init, .exit = zixine_exit_common,
    .start = zixine_start, .stop = zixine_stop, .owner = THIS_MODULE,
};

static int __init zixine_all_init(void) {
    cpufreq_register_governor(&gov_velocity);
    cpufreq_register_governor(&gov_overdrive);
    cpufreq_register_governor(&gov_ecopulse);
    return 0;
}

static void __exit zixine_all_exit(void) {
    cpufreq_unregister_governor(&gov_velocity);
    cpufreq_unregister_governor(&gov_overdrive);
    cpufreq_unregister_governor(&gov_ecopulse);
}

module_init(zixine_all_init);
module_exit(zixine_all_exit);

MODULE_AUTHOR("Zixine");
MODULE_DESCRIPTION("Zixine Governor Suite: Velocity, Overdrive, EcoPulse");
MODULE_LICENSE("GPL");
