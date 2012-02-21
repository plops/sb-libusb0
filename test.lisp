#+nil
(eval-when (:compile-toplevel :execute :load-toplevel)
 (push "/home/martin/0220/sb-libusb0/" asdf:*central-registry*))
(require :sb-libusb0)

#+nil
(sb-libusb0-internal::ensure-libusb0-initialized)

#+nil
(sb-libusb0-internal::bus-next (sb-libusb0-internal::get-busses*))

#+nil
(sb-libusb0-internal::bus-devices
 (sb-libusb0-internal::bus-next (sb-libusb0-internal::get-busses*)))

#+nil ;; ugly hack:
(sb-libusb0-internal::device-bus
 (sb-alien:sap-alien 
  (sb-alien:alien-sap
   (sb-libusb0-internal::bus-devices
    (sb-libusb0-internal::get-busses*)))
  (sb-alien:* sb-libusb0-internal::device)))

#+nil
(sb-libusb0-internal::device-next
 (sb-libusb0-internal::bus-devices
  (sb-libusb0-internal::get-busses*)))