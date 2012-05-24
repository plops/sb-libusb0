#+nil
(eval-when (:compile-toplevel :execute :load-toplevel)
 #-win64 (push "~/stage/sb-libusb0/" asdf:*central-registry*)
 #+win64 (setf asdf:*central-registry* 
	       '("c:/Users/martin/Desktop/stage/sb-libusb0/") )
 #+win32 (setf asdf:*central-registry* 
	       '("c:/Users/martin/Desktop/stage/sb-libusb0/") ))
(require :sb-libusb0)
;(asdf:oos 'asdf:compile-op :sb-libusb0 :verbose t)
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
(usbint::ensure-libusb0-initialized)
#+nil
(usbint::get-devices)
#+nil
(get-devices-by-ids :vendor-id #x19ec :product-id #x0300)

(defparameter *handle* nil)

#+nil
(progn
  (defparameter *handle* (usbint::usb-open 
			  (car (get-devices-by-ids :vendor-id #x19ec :product-id #x0300))))
  (when (sb-alien:null-alien *handle*)
    (break "error: forthdd device is probably not connected"))
  ;; i need to call set-configuration according to Downloads/libusbwin32_documentation.html
  (defparameter *conf* (usbint::set-configuration* *handle* 1))
  (defparameter *intf* (usbint::claim-interface :handle *handle* :interface 0)))



#+nil
(usbint::usb-close *handle*)


(defun forthdd-write (data)
  (with-ep #x04
    (bulk-write data :handle *handle*)))

(defun forthdd-read (bytes-to-read)
  (with-ep #x83
    (bulk-read bytes-to-read :handle *handle*)))

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
  (let* ((nd (length data))
	 (content (list (char-code #\W)
			(ldb (byte 8 8) address16)
			(ldb (byte 8 0) address16)
			(1- nd)))
	 (n (length content))
	 (a (make-byte-array (+ 1 n nd) content)))
    (dotimes (i nd)
      (setf (aref a (+ i n)) (aref data i)))
    (setf (aref a (+ n nd)) (checksum a (+ n nd)))
    a))

;; write(0x1234, 2, [0x02, 0x41, 0xF3])
;; 57 12 34
;; 02
;; 02 41 F3 
;; D6

#+nil
(format nil "~{~x ~}" (map 'list #'identity 
			   (pkg-write #x1234 #(2 #x41 #xf3))))
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
  ;; fetch one page from flash into ram
  (pkg-grab-or-burn (char-code #\G) blocknum32))

(defun pkg-burn (blocknum32)
  ;; write one page of data from forthdd controlers ram into flash
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

#+ni
(forthdd-write (pkg-call 2))
#+nil
(forthdd-write (pkg-call 1)) ;; reboot

#+nil
(forthdd-write (pkg-call #x23 '(3)))

(defun forthdd-talk (function &optional data)
  (forthdd-write (pkg-call function data))
  (forthdd-read 1024))

#+nil
(forthdd-talk #x0)

#+nil
(progn ;; get number of bitplanes
  (forthdd-talk #x17))
#+nil
(progn ;; get number of ro
  (forthdd-talk #x20))
#+nil
(progn ;; get selected ro
  (forthdd-talk #x21))
#+nil
(progn ;; get default ro
  (forthdd-talk #x22))
;; image 41 is default
#+nil
(progn ;;activate
  (forthdd-talk #x27))
#+nil
(progn ;;deactivate
  (forthdd-talk #x28))
#+nil
(progn ;; reload repertoir
  (forthdd-talk #x29))
#+NIL
(progn ;; get activation type
  (forthdd-talk #x25))
#+nil
(progn ;; get activation state
  (forthdd-talk #x26))

#+nil
(progn ;; switch image/running order
  (forthdd-talk #x23 '(0)))

#+nil
(dotimes (i 10)
 (loop for i below 40 do
      (sleep .3)
      (forthdd-talk #x23 (list i))))

#+nil
(defparameter *resp* (forthdd-read 1024))

#+nil
(map 'string #'code-char (forthdd-talk 2))

;; => "rTue Jan  5 10:20:15 2010
;; "


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

#|
#x17 getNumBitplanes
#x20 getROCount
#x21 getSelectedRO
#x22 getDefaultRO
#x23 setSelectedRO byte
#x24 setDefaultRO byte

|#


(defparameter cmds
  `((0 is-ap)
    (1 reboot)
    (2 timestamp)
    (3 version)
    (5 erase-block (blocknum 4))
    (#x17 get-num-bitplanes)
    (#x20 get-ro-count)
    (#x21 get-selected-ro)
    (#x22 get-default-ro)
    (#x23 set-selected-ro (num 1))
    (#x24 set-default-ro (num 1))
    (#x25 get-activation-type)
    (#x26 get-activation-state)
    (#x27 activate)
    (#x28 deactivate)
    (#x29 reload-repertoire)
    (#x30 save-settings)
    (#x31 set-led (brightness 1))
    (#x32 get-led)
    (#x33 set-flip-testpattern (out-ctrl 1))
    (#x34 get-flip-testpattern)
    (#x35 get-daughterboard-type)
    (#x36 adc-read (channel 1))
    (#x37 board-id)
    (#x38 display-type)
    (#x39 display-temp)
    (#x3b get-serial-num)))

(defconstant +EXT-FLASH-BASE+ #x01000000) ;; first page
(defconstant +EXT-FLASH-BUFFER+ #x0400) ;; start of flash buffer in RAM
(defconstant +EXT-FLASH-PAGE-SIZE+ #x0800)

#+nil
(time
 (progn ;; erase all, takes 43s
   (loop for page from #x01000000 below #x0100f000 by 64 do
	(check-ack
	 (erase-block page)))))
#+nil
(erase-block #x01000040)

#+nil
(loop for page from #x01000000 below #x01000f00 by 64 do
	(check-ack
	 (erase-block page)))

(defun erase-block (blocknum)
  "Erase the Flash block."
  (declare (type (unsigned-byte 32) blocknum))
  (forthdd-talk 5
		(loop for i below 32 by 8 collect
		   ;; msb first
		     (ldb (byte 8 (- 24 i)) blocknum))))

(defun check-ack (pkg)
  (unless (eq 'ack (slave-package pkg))
    (break "error, device didnt acknowledge: ~a" pkg)))

(defun erase-bitplane ()
  (check-ack
   (erase-block +EXT-FLASH-BASE+))
  (check-ack
   (erase-block (+ #x40 +EXT-FLASH-BASE+))))

#+nil
(erase-bitplane)


(defun write-ex (address16 data)
  (declare (type (unsigned-byte 16) address16))
  (forthdd-write (pkg-write address16 data))
  (check-ack (forthdd-read 1024)))

(defun burn-ex (blocknum32)
  (declare (type (unsigned-byte 32) blocknum32))
  (forthdd-write (pkg-burn blocknum32))
  (check-ack (forthdd-read 1024)))

(defun write-page (blocknum32 page)
  (declare (type (simple-array unsigned-byte 1) page)
	   (type (unsigned-byte 32) blocknum32))
  ;; write in chunks of 256 bytes
  ;; one page in external flash is 2048 bytes (8 packets)
  (dotimes (i 8)
    (write-ex (+ (* i 256) +EXT-FLASH-BUFFER+)
	      (subseq page 
		      (* 256 i)
		      (* 256 (1+ i)))))
  (burn-ex blocknum32))

#+nil
(forthdd-write (pkg-write (+ (* 0 256) +EXT-FLASH-BUFFER+)
			  (make-array 256 :element-type 'unsigned-byte)))
#+nil
(forthdd-read 1024)
#+nil
(pkg-write (+ (* 0 256) +EXT-FLASH-BUFFER+)
	   (make-array 256 :element-type 'unsigned-byte))

;; from 0x01 00 00 00 there are 960 blocks for images (120 MB)
;; from 0x01 00 F1 00 there are 60 blocks for more data (7.5 MB)

;; the image is filled from right to left and top to bottom
;; the first 160 bytes are the top row

;; each group of 8 bytes appear from left to right
;; each byte is displayed with the least significant
;; bit on the left

;; bytes: 152 153 154 .. 8 9 10 11 12 13 14 15 0 1 2 3 4 5 6 7
;; bits: ... 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7

(defun bitflip (b)
  ;; http://graphics.stanford.edu/~seander/bithacks.html#ReverseByteWith64BitsDiv
  (declare (type unsigned-byte b)
	   (values unsigned-byte &optional))
  (let ((spread #x0202020202)
	(select #x010884422010))
    (declare (type (unsigned-byte 64) spread select))
    (mod (logand (* b spread)
		 select)
	 1023)))
#+nil
(bitflip #b0000111)
#+nil
(bitflip #b10001111)


(defun create-bitplane (img)
  (declare (type (simple-array unsigned-byte (1024 1280)) img)
	   (values (simple-array unsigned-byte (1024 160)) &optional))
  (let* ((w 160)
	 (h 1024)
	 (bits (make-array (list h w)
			   :element-type 'unsigned-byte)))
    (dotimes (j h)
      (dotimes (i w)
	(dotimes (k 8)
	  (setf (ldb (byte 1 k) (aref bits j i))
		(if (= 0 (aref img j (+ k (* 8 i))))
		    0 1)))))
    bits))

(defun write-bitplane (img)
  ;; one bitplane contains 80 pages (smallest write unit) or 1.25
  ;; blocks (smallest erase unit)
  ;; 1280 x 1024 / 8 = 163840 bytes
  ;; 1 page = 2048 bytes
  ;; 1 block = 131072 bytes
  (declare (type (simple-array unsigned-byte (1024 160)) img))
  (let* ((img1 (sb-ext:array-storage-vector img))
	 (n (length img1))
	 (p +EXT-FLASH-PAGE-SIZE+))
    (dotimes (i (floor n p))
      (write-page (+ i +EXT-FLASH-BASE+)
		  (subseq img1
			  (* i p)
			  (* (1+ i) p))))))

#+nil
(progn ;; write some 8pixel stripes
 (let* ((w 160)
	(h 1024)
	(a (make-array (list h w) :element-type 'unsigned-byte)))
   (dotimes (j h)
     (dotimes (i w)
       (when (oddp i)
	 (setf (aref a j i) #xff))))
   (write-bitplane a)))

#+nil
(forthdd-talk #x29)
#+nil
(forthdd-talk #x23 '(0))
#+nil
(progn ;;deactivate
  (forthdd-talk #x28))
#+nil
(progn ;;activate
  (forthdd-talk #x27))
#+nil
(progn ;; write white image
  (let* ((a (make-array '(1024 160)
			:element-type 'unsigned-byte
			:initial-element #xff)))
    (write-bitplane a)))

#+nil
(erase-bitplane)
#+nil
(time 
 (let* ((h 1024)
	(w 1280)
	(a 
	 (make-array (list h w)
		     :element-type 'unsigned-byte)))
   (dotimes (i w)
     (dotimes (j h)
       (let ((r (sqrt (+ (expt (- i (floor w 2)) 2)
			 (expt (- j (floor h 2)) 2)))))
	 (when (< r 400)
	   (setf (aref a j i) 1)))))
   (write-bitplane (create-bitplane a))))
;; after uploading a bitplane, issue reload-repertoir rpc call
