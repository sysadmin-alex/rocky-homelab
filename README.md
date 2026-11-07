# rocky-homelab
Unattended Rocky Linux 10 installs: a Kickstart file baked into a bootable ISO with mkksiso

<img width="975" height="79" alt="image" src="https://github.com/user-attachments/assets/11092fd9-3b00-4a8a-a52b-11c4ff7d8105" />

<img width="975" height="70" alt="image" src="https://github.com/user-attachments/assets/c5cd4849-79d7-423b-b116-e67678ef31f2" />

sudo mkksiso --ks ks.cfg Rocky-10.2-x86_64-boot.iso ./auto.iso

xorriso -osirrox on -indev auto.iso   -extract /EFI/BOOT/grub.cfg efi-grub.cfg   -extract /boot/grub2/grub.cfg bios-grub.cfg

<img width="1088" height="56" alt="image" src="https://github.com/user-attachments/assets/34a970fd-beeb-4379-8160-b8c6b8156c16" />

student@rocky2:~/Documents$ xorriso \
  -indev auto.iso \
  -outdev final_kickstart.iso \
  -boot_image any replay \
  -map ./efi-grub.cfg /EFI/BOOT/grub.cfg \
  -map ./bios-grub.cfg /boot/grub2/grub.cfg
