# hdd-temp-monitor
Monitor disk temperature of disks passed through to a VM, so that you can contol fan speed according to that temp from the host (Proxmox, etc.)

I use it to control fan speed of my Proxmox server based on the temperature of the HDD disk on a SATA Controller that is passed through into a VM (it is Unraid in my case).

This project uses a DKMS module to fake a virtual temperature sensor on the host, which can then be read by `lm-sensors` and used to control fan speed.

Inside the VM, it uses a script to read the disk temperature calculate the disk's max temperature and can be collected by the host via `qemu-guest-agent`. The host system then collects this information and updates the virtual sensor using a systemd timer.
**Important Note:** this script won't wake up the disk, so if all the disks are idle, the temperature will be reported as 0°C.

## Installation

### Prerequisites

- A VM with a disk controller passed through (e.g., SATA controller).
- A disk attached to that controller.
- A Linux-based VM (e.g., Unraid, Ubuntu, etc.) with the necessary tools installed.
- A host system that supports DKMS (e.g., Proxmox, Ubuntu, etc.).

#### Steps

##### Host System (Proxmox, Ubuntu, etc.)

1. Clone the repository:

   ```bash
   git clone https://github.com/wxxsfxyzm/hdd-temp-monitor.git
   cd hdd-temp-monitor
   ```

2. Install the required packages:

   ```bash
   sudo apt update
   sudo apt install -y \
       build-essential \
       linux-headers-$(uname -r) \
       dkms \
       lm-sensors \
       fancontrol \
       jq
   ```

3. Copy the DKMS module to the appropriate directory:

   ```bash
   sudo cp -r virt-temp/virt-temp-1.0 /usr/src/
   ```

4. Register the DKMS module:

   ```bash
   sudo dkms add -m virt-temp -v 1.0
   ```
5. Build and install the DKMS module:

   ```bash
   sudo dkms build -m virt-temp -v 1.0
   sudo dkms install -m virt-temp -v 1.0
   ```
6. Load the module:

   ```bash
   sudo modprobe virt-temp
   ```
7. Verify that the module is loaded through `dmesg`:

   ```bash
   dmesg | grep virt-temp
   ```
   
   if you see output indicating that the module is loaded

   ```bash
   [    3.123456] virt-temp: device registered
   ```
   
   it means the installation was successful.

8. Configure sensors to read the temperature:
   - Run the script below to create a configuration file for the sensors, so that `sensors` can read the temperature from the virtual disk:

   ```bash
   echo -e 'chip "virt_temp-*"\n    label temp1 "HDD Max"' | sudo tee /etc/sensors.d/virt-temp.conf
   ```
   after that let sensors reload the configuration:
   
   ```bash
   sensors -s
   ```

   if you see no error, it means the configuration is successful.

9. Verify that the module is loaded and the temperature is being read:

   ```bash
   sensors
   ```
    
   You should see an output similar to:
    
   ```
   virt_temp-virtual-0
   Adapter: Virtual device
   HDD Max:       +0.0°C
   ```

   This indicates that the temperature sensor is working correctly.

#### VM Configuration (Unraid, Ubuntu, etc.)

1. Ensure that the VM has necessary permissions to access the disk controller and temperature sensors.
   - For Unraid, it works out of the box as long as the disk controller is passed through correctly.
2. Unraid runs it's system in memory, so you'd better put scripts you need into `/boot/config` folder to avoid losing them after reboot. 
   - In my case, I put them in `/boot/config/extras` folder, you can create this folder if it does not exist:

   ```bash
   mkdir -p /boot/config/extras
   ```

3. Upload two scripts in `vm/unraid` folder to your Unraid VM's `/boot/config/extras` folder 
(you can put them elsewhere, but remember to change the paths in the scripts accordingly):
   - `hdd-temp-monitor.sh`: This script will read the disk temperature and output it, it also have some other options:
   ```bash
   Usage: bash hdd_temp_monitor.sh [OPTIONS]
   Monitor disk temperatures and output maximum value

   Options:
     -t, --type [default|unraid]  Disk type context (default: default)
         default: include sda in monitoring
         unraid:  skip monitoring sda
     -i, --info [short|full]       Output information level (default: short)
         short: output only maximum temperature
         full:  output detailed disk information
     -h, --help                    Show this help message
   ```
   - `report_temp.sh`: boot partition is FAT32, which does not support Linux ACLs, and `qemu-guest-agent` does not support executing script with options inside a VM, so you need a wrapper script to run `hdd-temp-monitor.sh` with options, this script will be executed by `qemu-guest-agent` to report the temperature to the host.
4. remember to enable `qemu-guest-agent` in your `/boot/config/go` file, add the following line before the last line `/usr/local/sbin/emhttp`: 

   ```bash
   # Start qemu-ga
   /usr/bin/qemu-ga -l /tmp/qemu-ga.log -d
   ```

   a reboot is required for Unraid to apply the changes.

Other Linux-based VMs (like Ubuntu) can use the `hdd-temp-monitor.sh` script directly without the need for a wrapper script, just make sure to set the executable permission:

```bash
chmod +x hdd-temp-monitor.sh
```

Remember to install `qemu-guest-agent` and `smartmontools` if they are not already installed in your VM.

### Configure Host to Update Disk Temperature

1. Create a script on the host to fetch the disk temperature from the VM and update it in the host's sensors:

   ```bash
   sudo cp host/proxmox/virt-sensor-collector.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/virt-sensor-collector.sh
   ```
2. Create a systemd timer to run the script periodically:

   ```bash
   # /etc/systemd/system/hdd-temp.service
   [Unit]
   Description=Update Virtual HDD Temperature

   [Service]
   ExecStart=/usr/local/bin/virt-sensor-collector.sh
   ```

   ```bash
   # /etc/systemd/system/hdd-temp.timer
   [Unit]
   Description=Update HDD temp every 5 seconds

   [Timer]
   OnBootSec=5s
   OnUnitActiveSec=5s
   AccuracySec=1ms

   [Install]
   WantedBy=timers.target
   ```

3. Enable and start the timer:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable hdd-temp.timer
   sudo systemctl start hdd-temp.timer
   ```

4. Verify that the timer is running:

   ```bash
   systemctl status hdd-temp.timer
   ```

5. Check the disk temperature on the host:

   ```bash
   sensors
   ```

After following these steps, you should see the disk temperature being reported correctly on the host system.

### Optional: Configure Fan Control

1. Configure fancontrol:
   - Edit the fancontrol configuration file:

     ```bash
     sudo nano /etc/fancontrol
     ```

   - Set the appropriate parameters for your system. You can use the `pwmconfig` utility to help generate a basic configuration.
   - Start the fancontrol service:

     ```bash
     sudo systemctl start fancontrol
     sudo systemctl enable fancontrol
     ```

2. Monitor the disk temperature and fan speed:
   - You can use the `sensors` command to check the disk temperature.
   - The fan speed will be controlled automatically based on the temperature readings.

