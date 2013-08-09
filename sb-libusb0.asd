(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-grovel))

(defpackage #:sb-libusb0.system
  (:use #:asdf #:cl))
(in-package #:sb-libusb0.system)

(defsystem :sb-libusb0
  :depends-on (sb-grovel)
  :components ((:file "packages")
	       (:file "internal" :depends-on ("packages"))
	       (sb-grovel:grovel-constants-file "constants"
				      :package :sb-libusb0-internal
				      :depends-on ("internal" "packages"))))
