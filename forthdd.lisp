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
;; some docs on how an image is encoded
;; xpdf '/home/martin/from-uffz/pdfs2/Downloads/forthdd/AN0020AA_MetroLib_(Rev_D_onwards).pdf'

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
  (forthdd-talk #x23 '(10)))
#+nil
(dotimes (i 100)
  (sleep .1)
  (format t "~d~%" i)
  (progn ;; switch image/running order
    (forthdd-talk #x23 (list i))))

#+nil
(dotimes (i 10)
 (loop for i below 40 do
      (sleep .3)
      (forthdd-talk #x23 (list (random 36)))))

#+nil
(defparameter *resp* (forthdd-read 1024))

#+nil ;; timestamp
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

(defun erase-bitplane (&optional (image-number 0))
  (check-ack
   (erase-block (+ (* image-number #x40)
		   +EXT-FLASH-BASE+)))
  (check-ack
   (erase-block (+ (* (1+ image-number) #x40) 
		   +EXT-FLASH-BASE+))))

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
  (declare (type (simple-array (unsigned-byte 8) 1) page)
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
			  (make-array 256 :element-type '(unsigned-byte 8))))
#+nil
(forthdd-read 1024)
#+nil
(pkg-write (+ (* 0 256) +EXT-FLASH-BUFFER+)
	   (make-array 256 :element-type '(unsigned-byte 8)))

;; from 0x01 00 00 00 there are 960 blocks for images (120 MB)
;; from 0x01 00 F1 00 there are 60 blocks for more data (7.5 MB)

;; the image is filled from right to left and top to bottom
;; the first 160 bytes are the top row

;; each group of 8 bytes appear from left to right
;; each byte is displayed with the least significant
;; bit on the left

;; bytes: 152 153 154 .. 8 9 10 11 12 13 14 15 0 1 2 3 4 5 6 7
;; bits: ... 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7

(defun create-bitplane (img)
  (declare (type (simple-array (unsigned-byte 8) (1024 1280)) img)
	   (values (simple-array (unsigned-byte 8) (1024 160)) &optional))
  (let* ((w 160)
	 (h 1024)
	 (bits (make-array (list h w)
			   :element-type '(unsigned-byte 8))))
    (dotimes (j h)
      (dotimes (ii 20)
	(dotimes (i 8)
	  (let ((iii (+ i (* 8 ii)))
		(iii2 (+ (- 7 i) (* 8 ii))))
	    (dotimes (k 8)
	      (setf (ldb (byte 1 k) (aref bits j iii))
		    (if (= 0 (aref img j (+ k (* 8 iii2))))
			  0 1)))))))
    bits))



(defun write-bitplane (img &key (image-number 0))
  ;; one bitplane contains 80 pages (smallest write unit) or 1.25
  ;; blocks (smallest erase unit)
  ;; 5 images are stored in 4 blocks
  ;; 1280 x 1024 / 8 = 163840 bytes
  ;; 1 page = 2048 bytes
  ;; 1 block = 131072 bytes
  (declare (type (simple-array (unsigned-byte 8) (1024 160)) img))
  (let* ((img1 (sb-ext:array-storage-vector img))
	 (n (length img1))
	 (p +EXT-FLASH-PAGE-SIZE+))
    (dotimes (i (floor n p))
      (write-page (+ i (* 80 image-number) +EXT-FLASH-BASE+)
		  (subseq img1
			  (* i p)
			  (* (1+ i) p))))))

#+nil
(progn ;; write some 8pixel stripes
 (let* ((w 160)
	(h 1024)
	(a (make-array (list h w) :element-type '(unsigned-byte 8))))
   (dotimes (j h)
     (dotimes (i w)
       (when (oddp i)
	 (setf (aref a j i) #xff))))
   (write-bitplane a)))

#+nil
(progn ;; write white image
  (let* ((a (make-array '(1024 160)
			:element-type '(unsigned-byte 8)
			:initial-element #xff)))
    (write-bitplane a)))

#+nil
(erase-bitplane 0)
#+nil
(time 
 (let* ((h 1024)
	(w 1280)
	(a 
	 (make-array (list h w)
		     :element-type '(unsigned-byte 8))))
   (dotimes (i w)
     (dotimes (j h)
       (let ((r (sqrt (+ (expt (- i (floor w 2)) 2)
			 (expt (- j (floor h 2)) 2)))))
	 (when (< r 400)
	   (setf (aref a j i) 1)))))
   (write-bitplane (create-bitplane a)
		   :image-number 0)))
;; after uploading a bitplane, issue reload-repertoir rpc call
#+nil
(progn
 (progn ;;deactivate
   (forthdd-talk #x28))
 (progn ;; reload repertoir
   (forthdd-talk #x29))
 (progn ;;activate
   (forthdd-talk #x27))
 (progn ;; switch image/running order
   (forthdd-talk #x23 '(0))))

#+nil
(progn ;;deactivate
  (forthdd-talk #x28))
#+nil
(progn ;; reload repertoir
  (forthdd-talk #x29))
#+nil
(progn ;;activate
  (forthdd-talk #x27))
#+nil
(dotimes (i 103)
  (sleep .3)
 (progn ;; switch image/running order
   (forthdd-talk #x23 (list i))))

#+nil
(progn ;; switch image/running order
  (forthdd-talk #x23 '(19)))
#+nil
(progn ;; switch image/running order
  (forthdd-talk #x23 '(0)))

;; nr-n.pdf

(defun mother (k)
  (declare (type (integer 2) k))
  (floor (+ k 2) 4))

(defun left-daughter (k)
  (declare (type (integer 1) k))
  (+ (* 4 k) -2))

(defun right-daughter (k)
  (declare (type (integer 1) k))
  (+ (* 4 k) 1))

(defun which-daughter (k)
  (declare (type (integer 2) k)
	   (values (integer 0 3) &optional))
  (mod (+ 2 k) 4))

(defun total-boxes (level)
  (declare (type (integer 1) level))
  (/ (1- (expt 4 level))
     3))

#+nil
(list
  (loop for i from 1 below 6 collect (list i (total-boxes i)))
  (= 6 (mother 25))
  (= 22 (left-daughter 6))
  (= 25 (right-daughter 6))
  (= 5 (total-boxes 2))
  (= (+ 1 4 (* 4 4)) (total-boxes 3))
  (and (= 0 (which-daughter 2))
       (= 0 (which-daughter 6))
       (= 2 (which-daughter 84))))

(defun circle-in-box-p (radius center lo hi)
  (declare (type (complex double-float) center lo hi)
	   (type (double-float 0d0) radius))
  (not (or (< (- (realpart center) radius) (realpart lo))
	   (< (realpart hi) (+ (realpart center) radius))
	   (< (- (imagpart center) radius) (imagpart lo))
	   (< (imagpart hi) (+ (imagpart center) radius)))))

#+nil
(circle-in-box-p .1d0 #C(.5d0 .5d0) #C(0d0 0d0) #C(1d0 1d0))

(defparameter *blo* #C(0d0 0))
(defparameter *bscale* #C(1000d0 1000))

(defun .* (a b)
  (declare (type (complex double-float) a b))
  (complex (* (realpart a) (realpart b))
	   (* (imagpart a) (imagpart b))))


(defun get-box (k)
  (let ((offset (complex 0d0))
	(del 1d0)
	(kb 0))
    (loop while (< 1 k) do
	 (setf kb (which-daughter k))
	 (incf offset
	  (ecase kb
	    (0 0)
	    (1 (complex del))
	    (2 (complex 0d0 del))
	    (3 (complex del del))))
	 (setf k (mother k)
	       del (* del 2)))
    (let ((lo (+ *blo* (* (/ del) (.* *bscale* offset))))
	  (hi (+ *blo* (* (/ del) (.* *bscale*
				      (+ offset (complex 1d0 1d0)))))))
      (values lo hi))))

#+nil
(get-box 1)

(defun box-containing-circle (radius center &optional (level 4))
  "find smallest box, that contains the circle"
  (declare (type (complex double-float) center)
	   (type double-float radius)
	   (type integer level))
  (let ((kl 1)
	(kr 1)
	(k 1)
	(ks 1))
    (loop for p from 2 upto level do
	 (setf kl (left-daughter ks)
	       kr (right-daughter ks))
	 (loop for k from kl upto kr do ;; do any daughters contain circle ?
	      (multiple-value-bind (lo hi) (get-box k)
		(when (circle-in-box-p radius center lo hi)
		  (setf ks k)
		  (return)))) ;; return from immediatly enclosing loop
	 (when (< kr k) ;; no, discontinue
	   (return)))
    ks))
#+nil
(box-containing-circle 1d0 (complex 122d0 122))

(defun draw-quad-box (k &key (w 1280) (h 1024) (ox 0) (oy 0))
 (multiple-value-bind (lo hi)
     (get-box k)
   (let* ((sx (+ ox (floor (realpart lo)))) 
	  (sy (+ oy (floor (imagpart lo)))) 
	  (ex (+ ox (floor (realpart hi))))
	  (ey (+ oy (floor (imagpart hi))))
	  (a (make-array (list h w) :element-type '(unsigned-byte 8))))
     (loop for i from sx below ex do
	  (loop for j from sy below ey do
	       (setf (aref a j i) 255)))
     a)))

#+nil
(draw-quad-box 1)

(defun draw-disk (rad &key (w 1280) (h 1024) 
		  (x (floor w 2)) (y (floor h 2)))
  (declare (type double-float rad))
  (let ((a (make-array (list h w) :element-type '(unsigned-byte 8)
		       :initial-element 0))
	(rad2 (expt rad 2))
	(crad (ceiling rad)))
    (loop for j from (- y crad) upto (+ y crad) do
	 (loop for i from (- x crad) upto (+ x crad) do
	      (let ((r2 (+ (expt (- j y) 2d0)
			   (expt (- i x) 2d0))))
		(when (<= r2 rad2)
		  (setf (aref a j i) 255)))))
    a))

(defun draw-half-plane (&key (w 1280) (h 1024) 
			(x t) (pos (floor w 2)))
  (let ((a (make-array (list h w) :element-type '(unsigned-byte 8))))
    (loop for j from 0 below h do
	 (loop for i from 0 below pos do
	      (if x 
		  (setf (aref a j i) 255)
		  (setf (aref a i j) 255))))
    a))

(defun draw-grating-x (&key (w 1280) (h 1024) (period 2))
  (let ((a (make-array (list h w) :element-type '(unsigned-byte 8))))
    (dotimes (i w)
      (dotimes (j h)
	(setf (aref a j i) (if (< (mod i period) (floor period 2))
			       255
			       0))))
    a))

(defun draw-checker (&key (w 1280) (h 1024) (period 2))
  (let ((a (make-array (list h w) :element-type '(unsigned-byte 8))))
    (dotimes (i w)
      (dotimes (j h)
	(setf (aref a j i) 
	      (if (and (< (mod (+ (floor i period) (floor j period)) 2) 
			  1))
		  255 0))))
    a))

#+nil
(draw-checker :w 8 :h 8 :period 1)

#+nil
(write-bitplane 
 (create-bitplane
  (draw-quad-box 1 	 
		 :ox (floor (- 1280 512) 2)
		 :oy (floor (- 1024 512) 2))))
#+nil
(total-boxes 3)

#+nil
(* 4
 (ceiling (total-boxes 3) 5))

#+nil
(* 4
 (ceiling 40 5))

#+nil 
(time
 (loop for i from 0 below (* 4 (ceiling 500 5)) do
    ;; erase 4 blocks for 5 images
      (format t "~d~%" i)
      (erase-block (+ (* i #x40) +EXT-FLASH-BASE+))))

#+nil
(time ;; 10s for 5, 41s for 21 images
 (loop for i below (total-boxes 3) do
      (write-bitplane 
       (create-bitplane
	(draw-quad-box (1+ i) 
		       :ox (floor (- 1280 1000) 2)
		       :oy (floor (- 1024 1000) 2)))
       :image-number i)))

#+nil
(time ;; 71.5s for 36 images ;; 385s for 14x14 images ;; 196.6s for 10x10
 (progn
   (loop for i below 10 do
	(loop for j below 10 do
	     (write-bitplane 
	      (create-bitplane
	       (let ((w 1280)
		     (h 1024))
		 (format t "~a~%" (list j i))
		 (draw-disk 12d0 :w w :h h 
			    :x (+ 400 (* 50 i))
			    :y (+ 500 (* 50 j)))))
	      :image-number (+ (* 10 i) j))))
   (progn
     (write-bitplane (create-bitplane (draw-disk 125d0 
						 :x 650 :y 700))
		     :image-number 100)
     (write-bitplane (create-bitplane (draw-disk 64d0 
						 :x 650 :y 700))
		     :image-number 101)
     (write-bitplane (create-bitplane (draw-disk 32d0
						 :x 650 :y 700))
		     :image-number 101))))


#+nil
(time ;; 78.5s for 40 images
 (progn
   (loop for i below 20 do
	(format t "~d~%" i)
	(write-bitplane
	 (create-bitplane
	  (draw-half-plane :x t :pos (+ 500 (* 20 i))))
	 :image-number i))
   (loop for i below 20 do
	(format t "~d~%" (+ 20 i))
       (write-bitplane
	(create-bitplane
	 (draw-half-plane :x nil :pos (+ 500 (* 20 i))))
	:image-number (+ 20 i)))))

;; vertical edges 5..9 are visible 500..900 px
;; horizontal edges 15..19 are visible 500..900 px


#+nil
(time
 (loop for i below 40 do
      (format t "~d~%" i)
      (write-bitplane
       (create-bitplane
	(draw-checker :period (+ 1 i)))
       :image-number i)))