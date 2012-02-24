(require :sb-libusb0)

(defpackage :forthdd
  (:use :cl :sb-libusb0-internal))

(in-package :forthdd)

;; original python prototype 1214/ser/ser.py
;; /home/martin/wxga-forthdd/AN0005AA\ RS232\ Control\ Protocol\ for\ SXGA-R3\ Systems_0.pdf
;; if i had a graphics card, that is triggered with the camera, the dvi display should work
;; from-uffz/pdfs2/Downloads/forthdd/AN0015AA_RS-232_Control_Protocol_for_SXGA-3DM_Systems_0.pdf

#+nil
(usbint::get-product-id (car (get-devices-by-ids)))

#+nil
(get-devices-by-ids :vendor-id #x19ec :product-id #x0300)

(defparameter *handle* nil)

#+nil
(defparameter *handle* (usbint::usb-open 
			(car (get-devices-by-ids :vendor-id #x19ec :product-id #x0300))))

#+nil
(defparameter *intf* (usbint::claim-interface :handle *handle* :interface 0))

(defun forthdd-write (data)
  (with-ep #x04
    (bulk-write data :handle *handle*)))

(defun forthdd-read (bytes-to-read)
  (with-ep #x83
    (bulk-read bytes-to-read :handle *handle*)))

#+nil
(with-usb-open (car (get-devices-by-ids :vendor-id #x19ec
					:product-id #x0300))
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
	 (n (length content))
	 (a (make-byte-array (1+ n) content)))
    (setf (aref a n) (checksum a n))
    a))

(defun pkg-write (address16 data)
  (declare (type (unsigned-byte 16) address16))
  (let* ((content (list (char-code #\W)
			(ldb (byte 8 8) address16)
			(ldb (byte 8 0) address16)
			(1- (length data))))
	 (n (length content))
	 (a (make-byte-array (1+ n) content)))
    (setf (aref a n) (checksum a n))
    a))

#+nil
(pkg-read #x0101 01)

(defun pkg-grab-or-burn (code blocknum32)
  (declare (type (unsigned-byte 32) blocknum32))
  (declare (type (unsigned-byte 8) code))
  (let* ((content (list code
			(ldb (byte 8 24) blocknum32)
			(ldb (byte 8 16) blocknum32)
			(ldb (byte 8 8) blocknum32)
			(ldb (byte 8 0) blocknum32)))
	 (n (length content))
	 (a (make-byte-array (1+ n) content)))
    (setf (aref a n) (checksum a n))
    a))

(defun pkg-grab (blocknum32)
  (pkg-grab-or-burn (char-code #\G) blocknum32))

(defun pkg-burn (blocknum32)
  (pkg-grab-or-burn (char-code #\B) blocknum32))

(defun pkg-call (function &optional data)
  (declare (type (unsigned-byte 8) function))
  (push (length data) data)
  (push function data)
  (push (char-code #\C) data)
  (let* ((n (length data))
	 (a (make-byte-array (1+ n) data)))
    (setf (aref a n) (checksum a n))
    a))

#+nil
(pkg-call #x01 '(1 2 3))

#+nil
(forthdd-write (pkg-call 2))
#+nil
(defparameter *resp* (forthdd-read 1024))

;; (map 'string #'code-char *resp*)

;; => "rTue Jan  5 10:20:15 2010
;; "

#|
#x17 getNumBitplanes
#x20 getROCount
#x21 getSelectedRO
#x22 getDefaultRO
#x23 setSelectedRO byte
#x24 setDefaultRO byte

|#

(defun slave-package (pkg)
  (declare (type (simple-array (unsigned-byte 8) 1) pkg))
  (ecase (aref pkg 0)
    (97 'ack) ;; a 
    (101 'error) ;; e 
    (112 'pro) ;; p
    (120 'exc) ;; x 
    (114 'ret) ;; r
    (108 'log) ;; l
    ))