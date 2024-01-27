# GPI Case overlays

**At the time, only an overlay for the GPI Case 2 is available, as I only own this one, but feel free to submit overlays for other GPI Case models in merge requests.**

## Overview

These overlays are supposed to be cleaner replacements for the patch scripts provided by Retroflag for correct display and safe shutdown (Retroflag could have included such an overlay into an ID EEPROM so that none of these would be necessary, but whatever).

The main idea behind these is to get the GPI Case to work with unpatched distributions, such as Raspberry Pi OS (_Raspbian_) or RetroPie.

## Usage

Copy the binary device tree overlays (with `.dtbo` extension) into the `/boot/overlays` directory (or `/boot/firmware/overlays` on RPi OS Bookworm and later), then add the following section into `/boot/config.txt`:
```
[cm4]
dtoverlay=gpi-case-2
```
You may want to remove the `otg_mode=1` line if present as it prevents the use of USB peripherals.

And that's all for the main use case. The screen works with the KMS driver (not firmware KMS anymore) and switching the power button should trigger a `KEY_POWER` event (code 116) that systemd should catch and then execute a proper shutdown.

## Compiling device tree overlays

This repository also provide source of the device tree overlays in two forms: before and after preprocessing. The GPI Case overlay is built by merging other overlays together (with `ovmerge`) and some of the parent overlays may contain device tree includes in the form of Linux C headers, so the source needs to be preprocessed before being compiled with `dtc`.
To preprocess the overlay source `gpi-case-2-overlay.dts`:
```
cpp -nostdinc -undef -x assembler-with-cpp -I [path to linux kernel headers] gpi-case-2-overlay.dts gpi-case-2-overlay.dts.preproc
```
Then, to compile the preprocessed overlay source `gpi-case-2-overlay.dts.preproc`:
```
dtc -I dts -O dtb -o gpi-case-2.dtbo gpi-case-2-overlay.dts.preproc
```

## Technical details

The source overlay is built with already existing overlays provided with the kernel. The above line 
`dtoverlay=gpi-case-2` in `/boot/config.txt` could be replaced with:
```
dtoverlay=dwc2,dr_mode=host
dtoverlay=vc4-kms-dpi-generic
dtparam=hactive=640,hfp=41,hsync=40,hbp=41
dtparam=vactive=480,vfp=18,vsync=9,vbp=18
dtparam=clock-frequency=24000000,rgb666-padhi
dtparam=width-mm=60,height-mm=45
dtoverlay=gpio-led,gpio=27,active_low=1,label=power_enable
dtoverlay=gpio-shutdown,gpio_pin=26  
```
- `dtoverlay=dwc2,dr_mode=host` enables USB hosting on the USB-C port, meaning you can plug USB peripherals in.
- `dtoverlay=vc4-kms-dpi-generic` and the following `dtparams` configures the 3-inch display (DPI) with the proper timings in KMS. The `rgb666-padhi` parameter tells the kernel that only the 6 most significant bits are used for each color channel, meaning GPIO pins 10, 11, 18, 19, 26 and 27 are not used by the display (the later two of which will be important for safe shutdown).
- `dtoverlay=gpio-led,gpio=27,active_low=1,label=power_enable` and `dtoverlay=gpio-shutdown,gpio_pin=26` are related to safe shutdown. Actually, when you switch the power button of the GPI Case 2 back to off, GPIO 26 on the CM4 gets pulled down and power is cut immediately. It looks like GPIO 27 on the CM4 is also wired to power, so keeping it high with overlay `gpio-led` will keep the machine powered on despite switch off. Then, the CM4 can see the falling edge on GPIO 26 and consider it a `KEY_POWER` event thanks to overlay `gpio-shutdown`.

## TODO

- Overlays for other GPI Case models.
- Automatic display output switching with the dock: this one is special, I don't have a dock right now, my colleagues gifted me the GPI Case 2 as a gift, but the dock wasn't included. Retroflag doesn't sell them separately, but generic dock with HDMI output and HDMI adapters don't work with the GPI Case 2, because the video output signal from the USB-C port is directly HDMI, not DisplayPort as the active HDMI adapters usually expect. Retroflag's dock is basically proprietary or the only case of a HDMI Alt Mode USB-C dock I know of. But once I can get my hands on such a dock, I guess automatic switching will just be a matter of some udev rules.
