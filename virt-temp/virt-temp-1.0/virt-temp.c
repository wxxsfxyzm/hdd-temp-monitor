#include <linux/module.h>
#include <linux/device.h>
#include <linux/hwmon.h>
#include <linux/hwmon-sysfs.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/init.h>

static long temp = 0; // 模拟温度值，初始为0
static struct device* temp_dev; // 设备指针，用于注册hwmon设备

// 设备属性显示和存储函数
static ssize_t temp_show(struct device* dev,
    struct device_attribute* devattr,
    char* buf) {
    return sprintf(buf, "%ld\n", temp);
}

static ssize_t temp_store(struct device* dev,
    struct device_attribute* devattr,
    const char* buf, size_t count) {
    kstrtol(buf, 10, &temp);
    return count;
}

// 定义设备属性
static SENSOR_DEVICE_ATTR(temp1_input, 0644, temp_show, temp_store, 0);

// 设备属性数组，包含一个温度传感器属性
static struct attribute* temp_attributes[] = {
    &sensor_dev_attr_temp1_input.dev_attr.attr,
    NULL
};

static const struct attribute_group temp_attr_group = {
    .attrs = temp_attributes,
};

static int __init virt_temp_init(void) {
    // 属性组注册
    static const struct attribute_group* virt_temp_groups[] = {
        &temp_attr_group,
        NULL
    };

    temp_dev = hwmon_device_register_with_groups(
        NULL,
        "virt_temp",
        NULL,
        virt_temp_groups
    );

    // 检查设备注册是否成功
    if (IS_ERR(temp_dev)) {
        printk(KERN_ERR "virt-temp: registration failed\n");
        return PTR_ERR(temp_dev);
    }
    printk(KERN_INFO "virt-temp: device registered\n");
    return 0;
}

// 模块卸载函数
static void __exit virt_temp_exit(void) {
    hwmon_device_unregister(temp_dev);
    printk(KERN_INFO "virt-temp: device unregistered\n");
}

module_init(virt_temp_init);
module_exit(virt_temp_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("wxxsfxyzm");
MODULE_DESCRIPTION("Virtual Temperature Sensor");
