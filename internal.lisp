(in-package :sb-libusb0-internal)

(sb-alien:define-alien-type handle int)
(sb-alien:define-alien-type phandle (sb-alien:* handle))