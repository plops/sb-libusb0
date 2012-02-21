#+nil
(eval-when (:compile-toplevel :execute :load-toplevel)
 (push "/home/martin/0220/sb-libusb0/" asdf:*central-registry*))
(require :sb-libusb0)

#+nil
(sb-libusb0-internal::ensure-libusb0-initialized)

