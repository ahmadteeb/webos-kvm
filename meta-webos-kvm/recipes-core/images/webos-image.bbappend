# Bake the QEMU/KVM fixes into the image.

IMAGE_INSTALL:append = " webos-kvm-fixes"

ROOTFS_POSTPROCESS_COMMAND:append = " webos_kvm_rootfs_fixes;"

webos_kvm_rootfs_fixes() {
    # 1. Unversioned GL library names that WebAppMgr/Chromium dlopen()s.
    #    ("Failed to load GLES library" otherwise.)
    if [ -e ${IMAGE_ROOTFS}${libdir}/libGLESv2.so.2 ] && [ ! -e ${IMAGE_ROOTFS}${libdir}/libGLESv2.so ]; then
        ln -sf libGLESv2.so.2 ${IMAGE_ROOTFS}${libdir}/libGLESv2.so
    fi
    if [ -e ${IMAGE_ROOTFS}${libdir}/libEGL.so.1 ] && [ ! -e ${IMAGE_ROOTFS}${libdir}/libEGL.so ]; then
        ln -sf libEGL.so.1 ${IMAGE_ROOTFS}${libdir}/libEGL.so
    fi

    # 2. Atomic KMS off: virtio-gpu rejects the forced atomic commit (-22).
    F=${IMAGE_ROOTFS}${sysconfdir}/surface-manager.d/eglfs-integrations/eglfs_kms_webos.env
    if [ -f "$F" ]; then
        sed -i 's/QT_QPA_EGLFS_KMS_ATOMIC=1/QT_QPA_EGLFS_KMS_ATOMIC=0/' "$F"
    else
        bbwarn "webos-kvm: $F not found, atomic KMS not disabled (check the image layout)"
    fi
}
