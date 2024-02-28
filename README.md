# GUI + background service for the Arsenal Virtual RAM-disk driver

This project was born out of necessity. I have been using [ImDisk Toolkit](https://sourceforge.net/projects/imdisk-toolkit/) for years without any issues.
I particularly liked the ability to preload content to the RAM-disk from a local directory and synchronize the RAM-disk back on shutdown.
However, I started meeting issues when some newer software applications refused to work with my ImDisk-powered RAM-disk. 
One easy to reproduce case is if you install Chrome 86+ and then try to install any Chrome extension - you will get a popup window with an error message

```
ERR_CANT_FIND_TEMP_FOLDER
``` 

The underlying reason for the error is that ImDisk driver works in a special mode (Direct-IO) which bypasses Windows Volume Manager. 
This leads to a problem with the Win32 API function `GetFinalPathNameByHandle` - you can read the discussions at 

- [https://web.archive.org/web/20200805111419/http://reboot.pro/topic/22008-getfinalpathnamebyhandle-fails-with-error-invalid-function/](https://web.archive.org/web/20200805111419/http://reboot.pro/topic/22008-getfinalpathnamebyhandle-fails-with-error-invalid-function/)
- [https://web.archive.org/web/20200815180956/http://reboot.pro/topic/21152-possible-bug-or-incompatibility-in-imdisk/](https://web.archive.org/web/20200815180956/http://reboot.pro/topic/21152-possible-bug-or-incompatibility-in-imdisk/)  

The author of ImDisk drver created Arsenal driver which works in the normal `SCSI miniport` mode and is visible to the Windows Volume Manager.
He provides a console utility to create/remove RAM-disk(s) but no `Windows service` tool that will create a RAM-disk on boot - and certainly nothing similar to the ImDisk Toolkit that I was used to (and probably many other users).
The console utility is also dependent on the ImDisk CPL applet - which I did not quite like (from a developer's point of view). 

So I decided to create a GUI for configuring the parameters of the RAM-disk, plus a `Windows service` that will create the desired RAM-disk on boot and persist it on shutdown.
Of course, I did some research before deciding to start the development - there were other free and commercial RAM-disk tools working as `SCSI miniport` drivers 
but they either did not have the additional features of ImDisk Toolkit or they required a VHD image for preloading/persisting the RAM-disk contents
(and I preferred the usage of native filesystem instead of VHD image).

It took me about a week to extract the relevant code from the AIM (Arsenal Image Mounter) console utility and translate it from C++ to Objec Pascal.
After a lot of debugging and trials/errors I succeeded - and successfully replaced ImDisk Toolkit with my tools.
I have to admit that I was in a hurry and just needed a working solution - there were no attempts to make the code more robust or to implement complex features (like regex support in the list of folders excluded from synchronization at shutdown).

The code is provided "AS IS" in the hope that it will be useful to others. Testing was done only on Win7 x64 - most probably it will not work on XP.
The code requires Admin privileges and the Arsenal driver - which can be downloaded from its [official repository](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/tree/master/DriverSetup). 
Thanks to user `lazychris2000` here is a short instruction how to install the Arsenal driver:

### Hassle-free (automatic) way

- download [https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverSetup.7z](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverSetup.7z)
- extract the archive into some folder, for example `c:\arsenal`
- using an elevated Administrator command prompt, run the following commands:

```
c:
cd \arsenal\cli\x64\aim_ll.exe --install ..\..

```

- you should get something similar to the following

```
Detected Windows kernel version 10.0.19045.
Platform code: 'Win10'. Using port driver storport.sys.

Reading inf file...
Creating device object...
Installing driver for device...
Finished successfully.
```

### Manual way

- download [https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverFiles.zip](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverFiles.zip)
- extract the archive into some folder, for example `c:\arsenal`
- using Windows Explorer, open the appropriate subfolder - e.g. `Win8` or `Win8.1` or `Win10` or perhaps `Win7`
- point your mouse over `phdskmnt.inf` file in the given subfolder and click the **right** mouse button to open the context menu
- from this context menu, choose the item `Install` and the Arsenal driver will be installed. You should see it in the Device Manager as `Arsenal Image Mounter` under the group `Storage controllers`

You will need Delphi 7 and TNT-Unicode in order to compile the source code of **RamDiskUI** - or you can simply download the binary release. 
All pull requests are welcome.

# LICENSE

MIT License

Copyright (c) 2021 tmcdos

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
