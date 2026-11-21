SUMMARY = "Display config so the webOS OSE GUI works on QEMU/KVM (virtio-gpu)"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

inherit systemd allarch

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "webos-kvm-display.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = "file://webos-kvm-display file://webos-kvm-display.service"

do_install() {
    install -d ${D}${sbindir} ${D}${systemd_system_unitdir}
    install -m 0755 ${WORKDIR}/webos-kvm-display ${D}${sbindir}/webos-kvm-display
    install -m 0644 ${WORKDIR}/webos-kvm-display.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}"
