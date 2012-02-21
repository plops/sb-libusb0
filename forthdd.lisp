(require :sb-libusb0)

(defpackage :forthdd
  (:use :cl :sb-libusb0-internal))

(in-package :forthdd)

;; original python prototype 1214/ser/ser.py

#+nil
(with-usb-open (car (get-devices-by-ids :vendor-id #x19ec :product-id #x0300))
  (with-ep #x04
    (bulk-write )))

#+nil
(with-usb-open (car (get-devices-by-ids :vendor-id #x19ec :product-id #x0300))
  (with-ep #x83
    (bulk-read )))

(defun make-byte-array (n &optional initial-contents)
  (let ((a (make-array n :element-type '(unsigned-byte 8) :initial-element 0)))
    (loop for i below (min n (length initial-contents)) do
	 (setf (aref a i) (elt initial-contents i)))
    a))

(defun checksum (a &optional (n (length a)))
  (declare (type (simple-array (unsigned-byte 8) 1) a))
  (let ((r 0))
    (dotimes (i n)
      (incf r (aref a i))
      (when (< 255 r)
	(decf r 255)))
    r))

(defun pkg-read (address16 length-1)
  (declare (type (unsigned-byte 16) address16)
	   (type (unsigned-byte 8) length-1))
  (let* ((content (list (char-code #\R)
			(ldb (byte 8 8) address16)
			(ldb (byte 8 0) address16)
			length-1))
	 (a (make-byte-array (1+ (length content)) content)))
    (setf (aref a 4) (checksum a 4))
    a))

#+nil
(pkg-read #x0101 01)