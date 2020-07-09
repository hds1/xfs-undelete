#!/usr/bin/newlisp -c



;; XFS undelete, Heiko Schroeter, Nov 2019
;; University of Bremen IUP
;; Version 1.0

;; Usage:
;; xfs_undelete partition startInode restoreDir(FQN)
;; i.e. xfs_undelete "/dev/sda1" 17179869696 "/root/raid/restoreDir/home/Users"

;; You can get the startInode in an xfs_db session by traversing from the root inode
;; to /home/Users.
;; Change if need be in (doRootDir) function below.

;; Sample xfs_db session:
;; root@kubuntu:~# xfs_db -r /dev/sda1
;; xfs_db> sb 0
;; xfs_db> p
;; <...>
;; rootino = 512
;; <...>
;; xfs_db> inode 512
;; xfs_db> p
;; <...>
;; u3.sfdir3.list[0].namelen = 4
;; u3.sfdir3.list[0].offset = 0x60
;; u3.sfdir3.list[0].name = "home"
;; u3.sfdir3.list[0].inumber.i8 = 515
;; u3.sfdir3.list[0].filetype = 2
;; <...>
;; xfs_db> inode 515
;; xfs_db> p
;; <...>
;; u3.sfdir3.list[7].namelen = 4
;; u3.sfdir3.list[7].offset = 0x108
;; u3.sfdir3.list[7].name = "skiadir"
;; u3.sfdir3.list[7].inumber.i8 = 17179869696
;; u3.sfdir3.list[7].filetype = 2
;; <...>
;; xfs_db> inode 17179869696 <-- wanted inode of lost dir

;; Now start script: ./xfs_undelete "/dev/sda1" 17179869696 "/where/to/restore/dir/"

##############################################################################
;; License:
;; XFS undelete. Undelete accidently removed files/dirs and restore the dir structure.
;; Copyright (C) 2019 IUP University of Bremen

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.
##############################################################################

;; Motivation:
;; Some GB of deleted data needed to be restored as much as poss.
;; Available tools crashed or created anonymous files.
;; Since we had hundred thousands of files to recover, restoring
;; the directory structure plus files inside was mandatory.
;; Instead of looping over lost inodes this prog attempts to
;; decend from the root inode of the XFS partition into the leaves.

;; Usage/Usability:
;; WARNING: This is by no means a complete bulletproofed solution !
;; It did the job for us though.
;; You MAY need to ADOPT some things for YOUR XFS system.

;; Readings (Highly recommended) :
;; XFS Filesystem Disk Structures 3rd Edition
;; Copyright © 2006 Silicon Graphics Inc.
;; and
;; https://xfs.org/index.php/XFS_FAQ

;; strip trailing zeros of restored files with if need be:
;; sed -i '\x00*$' file

;; Restoring XFS 3 (Version 5) only !
;; XFS_DIR3_BLOCK_MAGIC    0x58444233        Ok
;; XFS_DIR3_DATA_MAGIC     0x58444433        Ok
;; XFS_DIR3_FREE_MAGIC     0x58444633        Ok
;; XFS_DINODE_MAGIC        0x494e Short/Long Ok

;; Restoring of Dirs and Files only ! No symlinks.
;; i.e. xfs file type 1 and 2

;; Compare two Dirs excluding file pattern:
;; diff -x "*._inode" -rq dir1 dir2

;; Recognized XFS blocks in Version 1.0:
;; short dinode with 8bytes inode numbers
;; 000:  49 4e 41 ed 03 01 00 00 00 00 00 00 00 00 00 00  INA.............
;; 010:  00 00 00 0a 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 020:  58 2c 29 39 31 c5 e8 10 54 d8 bf 31 18 5c 9a 6f  X..91...T..1...o
;; 030:  58 2c 29 39 31 c5 e8 10 00 00 00 00 00 00 00 9b  X..91...........
;; 040:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 050:  00 00 00 02 00 00 00 00 00 00 00 00 d9 b0 a1 e5  ................
;; 060:  ff ff ff ff 4d 14 87 ae 00 00 00 00 00 00 00 0c  ....M...........
;; 070:  00 00 00 01 00 00 00 28 00 00 00 00 00 00 00 00  ................
;; 080:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 090:  58 2c 29 39 1c ca cf f3 00 00 00 00 00 00 02 03  X..9............
;; 0a0:  9b 62 0a ba 3f 5d 4b f6 b6 cb 01 8c cf fc 51 5c  .b....K.......Q.
;; 0b0:  08 07 00 00 00 00 00 00 02 00 0e 00 60 61 62 61  .............aba
;; 0c0:  6e 64 6f 6e 65 64 2d 64 69 72 73 02 00 00 00 00  ndoned.dirs.....
;; 0d0:  80 00 02 00 04 00 80 68 6f 6d 65 02 00 00 00 01  .......home.....

;; short inode with 4bytes inode numbers
;; 000:  49 4e 41 ed 03 01 00 00  00 00 03 e8 00 00 03 e8 INA.............
;; 010:  00 00 00 03 00 00 00 00  00 00 00 00 00 00 00 00 ................
;; 020:  5d ef 4e 4b 2d e0 16 2a  5d ef 4e 3b 16 c0 c6 de ].NK-..*].N;....
;; 030:  5d ef 4e 4b 2d e0 16 2a  00 00 00 00 00 00 00 12 ].NK-..*........
;; 040:  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 ................
;; 050:  00 00 00 02 00 00 00 00  00 00 00 00 00 00 00 00 ................
;; 060:  ff ff ff ff a6 7a df e2  00 00 00 00 00 00 00 0f .....z..........
;; 070:  00 00 00 01 00 13 09 f6  00 00 00 00 00 00 00 00 ................
;; 080:  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 ................
;; 090:  5d ee 24 fe 00 a3 0a 48  00 00 00 00 00 00 00 60 ].$....H.......`
;; 0a0:  db 42 22 ae 78 b0 45 3b  b8 24 59 3b 78 ed cd 41 .B".x.E;.$Y;x..A
;; 0b0:  01 00 00 00 00 60 04 00  60 68 6f 6d 65 02 00 00 .....`..`home...
;; 0c0:  00 63 00 00 00 00 00 00  00 00 00 00 00 00 00 00 .c..............
;; 0d0:  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 ................

;; long dinode with fsblock extents
;; 000:  49 4e 41 ed 03 02 00 00 00 00 03 e8 00 00 00 64  INA............d
;; 010:  00 00 00 2a 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 020:  58 35 82 51 11 41 7d d1 5d b1 b5 00 07 0a a4 e5  X5.Q.A..........
;; 030:  5d b1 b5 00 07 0a a4 e5 00 00 00 00 00 00 10 00  ................
;; 040:  00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 01  ................
;; 050:  00 00 00 02 00 00 00 00 00 00 00 00 dd 0d 9d 52  ...............R
;; 060:  ff ff ff ff 68 5c b8 64 00 00 00 00 00 00 0a eb  ....h..d........
;; 070:  00 00 05 a0 00 38 b8 70 00 00 00 00 00 00 00 00  .....8.p........
;; 080:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 090:  58 2c 29 39 29 6d ad 04 00 00 00 04 00 00 02 00  X..9.m..........
;; 0a0:  9b 62 0a ba 3f 5d 4b f6 b6 cb 01 8c cf fc 51 5c  .b....K.......Q.
;; 0b0:  00 00 00 00 00 00 00 00 00 10 00 1b 37 00 00 01  ............7...
;; 0c0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................

;; xfs directory block
;; 000:  58 44 42 33 95 87 35 e5 00 00 00 04 00 06 bd c0  XDB3..5.........
;; 010:  00 00 05 a0 00 38 b8 70 9b 62 0a ba 3f 5d 4b f6  .....8.p.b....K.
;; 020:  b6 cb 01 8c cf fc 51 5c 00 00 00 04 00 00 02 00  ......Q.........
;; 030:  08 90 04 b8 00 60 03 88 06 70 00 30 54 5a 07 36  .........p.0TZ.6
;; 040:  00 00 00 04 00 00 02 00 01 2e 02 a8 23 c6 00 40  ................
;; 050:  00 00 00 00 00 00 02 03 02 2e 2e 02 67 4e 00 50  ............gN.P
;; 060:  ff ff 03 88 0d cb fa 15 04 73 63 69 61 07 00 60  .........scoa...
;; 070:  00 00 00 24 10 41 42 3e 08 2e 54 72 61 73 68 2d  .....AB...Trash.
;; 080:  30 02 da 40 8c e5 00 60 00 00 00 24 8e a7 de 38  0..............8
;; 090:  0a 2e 54 72 61 73 68 2d 36 30 30 02 f3 58 00 60  ..Trash.600..X..
;; 0a0:  00 00 00 25 0e 7b 86 20 07 52 45 53 54 4f 52 45  .........RESTORE
;; 0b0:  02 bb 6a 1f da 45 00 60 00 00 00 25 90 61 4b f5  ..j..E.......aK.
;; 0c0:  05 54 54 5f 44 42 02 80 1c 1f 35 78 b5 66 00 60  .TT.DB....5x.f..
;; 0d0:  00 00 00 26 0e f7 0c ca 05 61 6b 6f 63 68 02 25  .........akich..
;; 0e0:  fa 57 a6 1f e7 f6 00 60 00 00 00 26 8e 7f 12 23  .W..............


;; xfs directory data with dir (and or files) entries OK
;; 000:  58 44 44 33 27 bd dd 23 00 00 00 06 0d ee 4b 78  XDD3..........Kx
;; 010:  00 00 05 9f 00 38 01 78 9b 62 0a ba 3f 5d 4b f6  .....8.x.b....K.
;; 020:  b6 cb 01 8c cf fc 51 5c 00 00 00 06 0d eb ce 20  ......Q.........
;; 030:  00 60 08 d0 0a d0 00 20 0b 08 00 20 81 02 81 02  ................
;; 040:  00 00 00 06 0d eb ce 20 01 2e 02 02 81 02 00 40  "."
;; 050:  00 00 00 04 00 00 02 00 02 2e 2e 02 81 02 00 50  ".."
;; 060:  ff ff 08 d0 0e ab da 37 0a 44 41 54 41 5f 42 41  .......7.DATA.BA
;; 070:  53 45 53 07 81 02 00 60 00 00 00 24 8f 3a a0 08  SES.............
;; 080:  04 2e 54 65 58 02 00 60 00 00 00 25 0f 2e 38 2b  ..TeX.........8.
;; 090:  09 2e 63 65 74 61 62 6c 65 73 02 02 81 02 00 60  ..cetables......
;; 0a0:  00 00 00 25 91 18 d0 1e 03 2e 64 74 02 02 00 60  ..........dt....
;; 0b0:  00 00 00 26 0f e5 70 09 08 2e 65 6d 61 63 73 2e  ......p...emacs.
;; 0c0:  64 02 81 02 81 02 00 60 00 00 00 26 90 49 d0 1c  d............I..
;; 0d0:  03 2e 66 6d 02 02 00 60 00 00 00 27 10 35 0a 0c  ..fm.........5..

;; xfs directory data with files only entries BROKEN
;; 000:  58 44 44 33 3b b0 e7 82 00 00 00 1b 0e 99 8d c0  XDD3............
;; 010:  00 00 00 13 00 0a d3 a8 9b 62 0a ba 3f 5d 4b f6  .........b....K.
;; 020:  b6 cb 01 8c cf fc 51 5c 00 00 00 1b 0e 99 c0 2e  ......Q.........
;; 030:  00 00 00 00 00 00 00 00 00 00 00 00 68 61 6c 6d  No "." or ".."
;; 040:  00 00 00 1b 0e 99 f9 a1 31 53 43 49 41 5f 4f 4c  ........1SCIA.OL
;; 050:  6c 69 6d 62 5f 32 30 31 31 30 31 30 35 5f 30 36  limb.20110105.06
;; 060:  33 31 32 39 5f 30 31 5f 55 56 31 5f 4e 4f 32 5f  3129.01.UV1.NO2.
;; 070:  6b 65 72 6e 65 6c 2e 64 61 74 01 20 30 34 00 40  kernel.dat..04..
;; 080:  00 00 00 1b 0e 99 f9 a2 2f 53 43 49 41 5f 4f 4c  .........SCIA.OL
;; 090:  6c 69 6d 62 5f 32 30 31 31 30 31 30 35 5f 30 36  limb.20110105.06
;; 0a0:  33 31 32 39 5f 30 31 5f 55 56 31 5f 4e 4f 32 5f  3129.01.UV1.NO2.
;; 0b0:  6d 61 69 6e 2e 64 61 74 01 32 2f 50 44 2f 00 80  main.dat.2.PD...
;; 0c0:  00 00 00 1b 0e 99 f9 a3 33 53 43 49 41 5f 4f 4c  ........3SCIA.OL
;; 0d0:  6c 69 6d 62 5f 32 30 31 31 30 31 30 35 5f 30 36  limb.20110105.06
;; 0e0:  33 31 32 39 5f 30 31 5f 55 56 31 5f 4e 4f 32 5f  3129.01.UV1.NO2.
;; 0f0:  6e 75 6d 5f 64 65 6e 73 2e 64 61 74 01 4c 00 c0  num.dens.dat.L..



;; CHECK this out:
;; xfs_db> fsblock
;; current fsblock is 14526134277
;; xfs_db> inode
;; current inode number is 116209074222
;; xfs_db> type text
;; xfs_db> p
;; 000:  49 4e 00 00 03 02 00 00 00 00 03 f7 00 00 00 64  IN.............d
;; 010:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 020:  58 36 7f c2 1f 93 38 3c 5d b1 a8 46 33 ab 77 1a  X6....8....F3.w.
;; 030:  5d b1 a8 46 34 53 4f db 00 00 00 00 00 00 00 0a  ...F4SO.........
;; 040:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 050:  00 00 00 02 00 00 00 00 00 00 00 00 6d 5d 0b f8  ............m...
;; 060:  ff ff ff ff b6 56 06 76 00 00 00 00 00 00 9b d7  .....V.v........
;; 070:  00 00 05 9f 00 3a 6d c0 00 00 00 00 00 00 00 00  ......m.........
;; 080:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
;; 090:  58 36 7e 43 1b c2 2f 73 00 00 00 1b 0e 99 c0 2e  X6.C...s........
;; 0a0:  9b 62 0a ba 3f 5d 4b f6 b6 cb 01 8c cf fc 51 5c  .b....K.......Q.

;; restored fsblock of 0xb0 entry:  6c 3a 67 97 00 00 08
;; 0b0:  00 01 00 01 00 00 00 00 00 00 00 00 97 00 00 08  ................
;; 0c0:  00 00 00 00 00 00 10 00 00 6c 3a 67 a0 00 00 40  .........l.g....
;; 0d0:  00 00 00 00 00 00 90 00 00 6c 3a 67 e7 00 00 08  .........l.g....
;; 0e0:  00 00 00 00 00 00 a0 00 00 6c 3a 67 f0 00 00 07  .........l.g....
;; Hash from here
;; 0f0:  00 00 00 01 00 00 00 00 00 6c 4a 67 97 00 00 11  .........lJg....
;; 100:  00 00 00 02 00 00 00 00 00 6c 5a 67 97 00 00 01  .........lZg....


;; CREATION = flag to actually write recovered items to disk
;; If nil only printouts will be done, for debugging purposes.
(setf CREATION true)
(global 'CREATION)

;; Restoring XFS 3 (Version 5) only !
;; XFS_DIR3_BLOCK_MAGIC    0x58444233        Ok
;; XFS_DIR3_DATA_MAGIC     0x58444433        Ok
;; XFS_DINODE_MAGIC        0x494e Short/Long Ok
(constant (global 'XDB3) 1)
(constant (global 'XDD3) 2)
(constant (global 'DINS) 3)
(constant (global 'DINL) 4)
(constant (global 'NON) -1)

(constant (global 'XFS_FILE) 1) ;; xfs file type
(constant (global 'XFS_DIR)  2) ;; xfs dir type
;; (constant (global 'LOCAL_OR_EXTENT) 0x5) ;; buf[0x5] = 1 -> local inode; = 2 inode with extents

(setf RECCOUNTER 50) ;; limit recursion depth to NUM
(global 'RECCOUNTER)


;; Dont allow control chars in filename and Extended ASCII chars
(setf FORBIDCHARS (regex-comp "[\\x00-\\x1F|\\x7F|\\x80-\\xFF]+"))
(global 'FORBIDCHARS)

;; Create a global inode content buffer,
;; so that we dont pass it around on stack.
;; Every Inode/Dir content is saved in this reused
;; global Buffer !
;; (setf GLOBALBUFFER nil)
;; (global 'GLOBALBUFFER)

;; buffer to be passed by reference
(set 'GBUF:GBUF (dup "A" (* 1024 1024 1024))) ;; 1GB Buffer

;; global superblock hash
(new Tree 'SB)

;; Global inode memoizer for directories only.
;; We save them to prevent larger recursion circles.
;; inode num -> 1  (just any value, we want the hash functionality)
(new Tree 'XFSNODES)

####################################################
#           XFS address conversion
#       Taken mainly from xfs_db convert.c
####################################################

;; from xfs_format.h:
;; #define BBSHIFT               9
;; #define BBSIZE                (1<<BBSHIFT)
;; #define BTOBB(bytes)  (((__u64)(bytes) + BBSIZE - 1) >> BBSHIFT)
;; #define BTOBBT(bytes) ((__u64)(bytes) >> BBSHIFT)
;; #define BBTOB(bbs)    ((bbs) << BBSHIFT)

;; #define	XFS_INO_MASK(k)			(uint32_t)((1ULL << (k)) - 1)
;;
;; #define	XFS_INO_AGBNO_BITS(mp)		(mp)->m_sb.sb_agblklog
;; #define	XFS_INO_AGINO_BITS(mp)		(mp)->m_agino_log
;; #define	XFS_INO_AGNO_BITS(mp)		(mp)->m_agno_log
;; #define	XFS_INO_BITS(mp)		\
;; 	XFS_INO_AGNO_BITS(mp) + XFS_INO_AGINO_BITS(mp)
;;
;; #define	XFS_AGINO_TO_AGBNO(mp,i)	((i) >> XFS_INO_OFFSET_BITS(mp))
;; #define	XFS_AGINO_TO_OFFSET(mp,i)	\
;; 	((i) & XFS_INO_MASK(XFS_INO_OFFSET_BITS(mp)))
;; #define	XFS_OFFBNO_TO_AGINO(mp,b,o)	\
;; 	((xfs_agino_t)(((b) << XFS_INO_OFFSET_BITS(mp)) | (o)))
;; #define	XFS_FSB_TO_INO(mp, b)	((xfs_ino_t)((b) << XFS_INO_OFFSET_BITS(mp)))

;; #define	XFS_MAXINUMBER		((xfs_ino_t)((1ULL << 56) - 1ULL))
;; #define	XFS_MAXINUMBER_32	((xfs_ino_t)((1ULL << 32) - 1ULL))

;; #define	XFS_INO_OFFSET_BITS(mp)		(mp)->m_sb.sb_inopblog
;; #define	XFS_INO_TO_OFFSET(mp,i)		\
;; 	((int)(i) & XFS_INO_MASK(XFS_INO_OFFSET_BITS(mp)))

;; from xfs sources
(constant (global 'bbshift) 9)

;; ## From XFS sources; definitons and functions
;; ;; mp->m_agino_log = sbp->sb_inopblog + sbp->sb_agblklog
;; (setf ino_agino_bits (+ agblklog inopblog)) ;; sb inodelog

;; ;; uint8_t  m_blkbb_log;    /* blocklog - BBSHIFT */
;; (setf blkbb_log (- blocklog bbshift))

;; ## TEST TEST
;; ## From Superblock
;; (setf ino_offset_bits 3) ;; sb inopblog
;; (setf ino_agbno_bits 28) ;; sb agblklog
;; (setf agblklog 28) ;; sb agblklog
;; (setf agblocks 268435392) ;; sb agblocks
;; (setf blocklog 12)
;; (setf inopblog 3)
;; (setf inodelog 9)

;; #define	XFS_AGB_TO_AGINO(mp, b)	((xfs_agino_t)((b) << XFS_INO_OFFSET_BITS(mp)))
(define (xfs_agb_to_agino agb)
  (& 0xffffffff (<< agb (SB "ino_offset_bits")))) ;; xfs_agino_t = unsigned 32bit

;; #define	XFS_AGINO_TO_INO(mp,a,i)	\
;; 	(((xfs_ino_t)(a) << XFS_INO_AGINO_BITS(mp)) | (i))
(define (xfs_agino_to_ino agino i)
  (| (<< agino (SB "ino_agino_bits")) i))

;; define   XFS_FSB_TO_INO(mp, b)   ((xfs_ino_t)((b) << XFS_INO_OFFSET_BITS(mp)))
(define (xfs_fsb_to_inode fsb)
  (<< fsb (SB "ino_offset_bits")))

;; from xfs_format.h
;; #define	XFS_INO_TO_AGNO(mp,i)		\
;; 	((xfs_agnumber_t)((i) >> XFS_INO_AGINO_BITS(mp)))
(define (xfs_ino_to_agno inode)
  (>> inode (SB "ino_agino_bits")))

;; #define	XFS_INO_MASK(k)			(uint32_t)((1ULL << (k)) - 1)
(define (xfs_ino_mask k)
  (- (<< 1 k) 1))

;; #define	XFS_INO_TO_AGINO(mp,i)		\
;; 	((xfs_agino_t)(i) & XFS_INO_MASK(XFS_INO_AGINO_BITS(mp)))
(define (xfs_ino_to_agino inode)
  (& inode (xfs_ino_mask (SB "ino_agino_bits"))))

;; define XFS_AGB_TO_FSB(mp,agno,agbno)	\
;; 	(((xfs_fsblock_t)(agno) << (mp)->m_sb.sb_agblklog) | (agbno))
(define (xfs_agb_to_fsb agno agbno)
  (| (<< agno (SB "agblklog") agbno)))

;; #define	XFS_INO_TO_AGBNO(mp,i)		\
;; 	(((xfs_agblock_t)(i) >> XFS_INO_OFFSET_BITS(mp)) & \
;; 		XFS_INO_MASK(XFS_INO_AGBNO_BITS(mp)))
(define (xfs_ino_to_agbno  inode)
  (& (>> inode (SB "ino_offset_bits"))
     (xfs_ino_mask (SB "ino_agbno_bits"))))

;; #define	XFS_INO_TO_FSB(mp,i)		\
;; 	XFS_AGB_TO_FSB(mp, XFS_INO_TO_AGNO(mp,i), XFS_INO_TO_AGBNO(mp,i))
(define (xfs_ino_to_fsb inode)
  (xfs_agb_to_fsb (xfs_ino_to_agno inode)
                  (xfs_ino_to_agbno inode)))

;; #define	XFS_FSB_TO_AGNO(mp,fsbno)	\
;; 	((xfs_agnumber_t)((fsbno) >> (mp)->m_sb.sb_agblklog))
(define (xfs_fsb_to_agno fsbno)
  (>> fsbno (SB "agblklog")))

;; static inline uint32_t xfs_mask32lo(int n)
;;         return ((uint32_t)1 << (n)) - 1;
(define (xfs_mask32lo n) (- (<< 1 n) 1))
;; #define	XFS_FSB_TO_AGBNO(mp,fsbno)	\
;;  ((xfs_agblock_t)((fsbno) & xfs_mask32lo((mp)->m_sb.sb_agblklog)))
(define (xfs_fsb_to_agbno fsbno)
  (& fsbno (xfs_mask32lo (SB "agblklog"))))

### xfs_gsb_to_bb NOT CORRECT, DONT USE !
;; #define	XFS_FSB_TO_BB(mp,fsbno)	((fsbno) << (mp)->m_blkbb_log)
(define (xfs_fsb_to_bb fsbno)
  (<< fsbno (SB "blkbb_log")))

;; #define	XFS_AGB_TO_DADDR(mp,agno,agbno)	\
;;	((xfs_daddr_t)XFS_FSB_TO_BB(mp, \
;;		(xfs_fsblock_t)(agno) * (mp)->m_sb.sb_agblocks + (agbno)))
(define (xfs_agb_to_daddr agno agbno)
  (xfs_fsb_to_bb (+ (* agno (SB "agblocks") agbno))))

;; #define	XFS_FSB_TO_DADDR(mp,fsbno)	XFS_AGB_TO_DADDR(mp, \
;;			XFS_FSB_TO_AGNO(mp,fsbno), XFS_FSB_TO_AGBNO(mp,fsbno))
(define (xfs_fsb_to_daddr fsbno)
  (xfs_agb_to_daddr (xfs_fsb_to_agno fsbno) (xfs_fsb_to_agbno fsbno)))

(define (xfs_ino_to_daddr inode)
  (xfs_fsb_to_daddr (xfs_ino_to_fsb inode)))

;; #define XFS_DADDR_TO_FSB(mp,d)  XFS_AGB_TO_FSB(mp, \
;;         xfs_daddr_to_agno(mp,d), xfs_daddr_to_agbno(mp,d))
(define (xfs_daddr_to_fsb daddr)
  (xfs_agb_to_fsb (xfs_daddr_to_agno daddr) (xfs_daddr_to_agbno daddr)))

;; #define XFS_AGB_TO_FSB(mp,agno,agbno)   \
;;         (((xfs_fsblock_t)(agno) << (mp)->m_sb.sb_agblklog) | (agbno))
(define (xfs_agb_to_fsb agno agbno)
  (| (<< agno (SB "agblklog") agbno)))

;; #define XFS_BB_TO_FSBT(mp,bb) \
;;         ((bb) >> (mp)->m_blkbb_log)
(define (xfs_bb_to_fsbt bb)
  (>> bb (SB "blkbb_log")))

;; #define xfs_daddr_to_agno(mp,d) \
;;        ((xfs_agnumber_t)(XFS_BB_TO_FSBT(mp, d) / (mp)->m_sb.sb_agblocks))
(define (xfs_daddr_to_agno daddr)
  (/ (xfs_bb_to_fsbt daddr) (SB "agblocks")))

;; #define xfs_daddr_to_agbno(mp,d) \
;;        ((xfs_agblock_t)(XFS_BB_TO_FSBT(mp, d) % (mp)->m_sb.sb_agblocks))
(define (xfs_daddr_to_agbno daddr)
  (% (xfs_bb_to_fsbt daddr) (SB "agblocks")))


;; #define agblock_to_bytes(x)     \
;;        ((uint64_t)(x) << mp->m_sb.sb_blocklog)
(define (xfs_agblock_to_bytes agblk)
  (<< agblk (SB "blocklog")))

;; #define agino_to_bytes(x)       \
;;        ((uint64_t)(x) << mp->m_sb.sb_inodelog)
(define (xfs_agino_to_bytes agino)
  (<< agino (SB "inodelog")))

;; #define agnumber_to_bytes(x)    \
;;        agblock_to_bytes((uint64_t)(x) * mp->m_sb.sb_agblocks)
(define (xfs_agnumber_to_bytes ag)
  (xfs_agblock_to_bytes (* ag (SB "agblocks"))))

;; #define daddr_to_bytes(x)       \
;;     ((uint64_t)(x) << BBSHIFT)
(define (xfs_daddr_to_bytes daddr)
  (<< daddr bbshift))

;; #define fsblock_to_bytes(x)     \
;;        (agnumber_to_bytes(XFS_FSB_TO_AGNO(mp, (x))) + \
;;         agblock_to_bytes(XFS_FSB_TO_AGBNO(mp, (x))))
(define (xfs_fsb_to_bytes fsb)
  (+ (xfs_agnumber_to_bytes (xfs_fsb_to_agno fsb))
     (xfs_agblock_to_bytes  (xfs_fsb_to_agbno fsb))))

;; #define ino_to_bytes(x)         \
;;        (agnumber_to_bytes(XFS_INO_TO_AGNO(mp, (x))) + \
;;         agino_to_bytes(XFS_INO_TO_AGINO(mp, (x))))
(define (xfs_ino_to_bytes inode)
  (+ (xfs_agnumber_to_bytes (xfs_ino_to_agno inode))
     (xfs_agino_to_bytes    (xfs_ino_to_agino inode))))

;;  #define inoidx_to_bytes(x)      \
;;        ((uint64_t)(x) << mp->m_sb.sb_inodelog)
(define (xfs_inodx_to_bytes inox)
  (<< inox (SB "inodelog")))

;; case CT_INO:
;;      v = XFS_AGINO_TO_INO(mp, xfs_daddr_to_agno(mp, v >> BBSHIFT),
;;          (v >> mp->m_sb.sb_inodelog) %
;;          XFS_AGB_TO_AGINO(mp, mp->m_sb.sb_agblocks));
(define (xfs_bytes_to_inode bytes)
  (xfs_agino_to_ino (xfs_daddr_to_agno (>> bytes bbshift))
                    (% (>> bytes (SB "inodelog"))
                       (xfs_agb_to_agino (SB "agblocks")))))

(define (xfs_fsb_to_inode fsb)
  (xfs_bytes_to_inode (xfs_fsb_to_bytes fsb)))

(define (xfs_bytes_to_daddr bytes)
  (>> bytes bbshift))

####################################################
#           HELPER
####################################################
(define (slice1 buf offset)
  (first (unpack ">b" (slice buf offset 1))))
(define (slice2 buf offset)
  (first (unpack ">u" (slice buf offset 2))))
(define (slice4 buf offset)
  (first (unpack ">lu" (slice buf offset 4))))
(define (slice8 buf offset)
  (first (unpack ">Lu" (slice buf offset 8))))
(define (slice16 buf offset)
  (slice buf offset 16))
(define (slice32 buf offset)
  (slice buf offset 32))

(define (printHash hdr hash)
  (println hdr)
  ;; printHash: Helper to print values of Dir Entry Hash
  (dolist (item (hash))
    (println " " (item 0) " --> " (item 1))))

(define (hexDump buf size)
  ;; print #size of byte of buf in hex format
  (for (lines 0 (/ size 16))
    (print (format "%03x:  " (* 16 lines)))
    (for (i 0 15)
      (print (format "%02x " (slice1 buf (+ (* 16 lines) i)))))
    (print " ")
    (for (i 0 15)
      (let ((character (slice1 buf (+ (* 16 lines) i))))
        (if (and (> character 0x21)(< character 0x7e))
            (print (char character))
            (print "."))))
    (println)))

(define (readSuperblock)
  ;; XFS superblock takes "sb_sectsize" space.
  ;; Read sectsize and then sb.
  ;; Needed vars saved in global superblock hash
  (let ((sb_buffer nil))
    (seek DISK 0)
    (read DISK sb_buffer 512) ;; get sectsize at offset 0x66
    (setf sb_sectsize (first (unpack ">u" (slice sb_buffer 0x66 2))))
    (seek DISK 0) ;; reread superblock with true sectsize
    (read DISK sb_buffer sb_sectsize)
    (SB "blocksize" (slice4 sb_buffer 0x04))
    (SB "dblocks"   (slice8 sb_buffer 0x08))
    (SB "rootino"   (slice8 sb_buffer 0x38))
    (SB "agblocks"  (slice4 sb_buffer 0x54))
    (SB "inodesize" (slice2 sb_buffer 0x68))
    (SB "blocklog"  (slice1 sb_buffer 0x78))
    (SB "inodelog"  (slice1 sb_buffer 0x7a))
    (SB "inopblog"  (slice1 sb_buffer 0x7b))
    (SB "agblklog"  (slice1 sb_buffer 0x7c))
    (SB "icount"    (slice8 sb_buffer 0x80))
    (SB "ifree"     (slice8 sb_buffer 0x88))
    (SB "dirblklog" (slice1 sb_buffer 0xbc))
    ;; ino_offset_bits = sb inopblog
    (SB "ino_offset_bits" (SB "inopblog"))
     ;; ino_agbno_bits = sb agblklog
    (SB "ino_agbno_bits" (SB "agblklog"))
    ;; From XFS sources; definitons and functions
    ;; mp->m_agino_log = sbp->sb_inopblog + sbp->sb_agblklog
    (SB "ino_agino_bits" (+ (SB "agblklog")(SB "inopblog"))) ;; sb inodelog
    ;; uint8_t  m_blkbb_log;    /* blocklog - BBSHIFT */
    (SB "blkbb_log" (- (SB "blocklog") bbshift))
    ;; size of a "directory block" is defined by sb_blocksize * (pow 2 sb_dirblklog)
    (SB "dirsize" (* (SB "blocksize") (pow 2 (SB "dirblklog"))))))

####################################################
#           INODE fiddling
####################################################

(define (padLongInodes num)
  ;; align to multiple of 8
  ;; wrong: (+ 8 (* 8 (/ num 8)))
  ;; should be same result as: (++ pointer (* 8 (int (ceil (div (+ 12 numchars) 8))))))
  (+ 8 (<< (>> (+ num -1) 3) 3)))

(define (readFsblock fsblockLst buf)
  ;; fsblockLst = (offset fsb #blocks)
  ;; read content of fsblock into buf
  (let ((byteoffset (xfs_fsb_to_bytes (nth 1 fsblockLst))))
    (seek DISK byteoffset)
    (read DISK buf (* (SB "blocksize") (last fsblockLst))))) ;; FIXME: limit size

(define (readByteOffsetBlocks byteOffsetLst buf)
  ;; byteOffsetLst = (offset byteOffsetOnDisk #blocks)
  ;; read content of fsblock into buf
  (let ((byteoffset (nth 1 byteOffsetLst)))
    (seek DISK byteoffset)
    (read DISK buf (* (SB "blocksize") (last byteOffsetLst))))) ;; FIXME: limit size


(define (getInodeType buf)
  ;; inode binary in buf
  ;; Restoring XFS 3 (Version 5) only !
  ;; XFS_DIR3_BLOCK_MAGIC    0x58444233        Ok
  ;; XFS_DIR3_DATA_MAGIC     0x58444433        Ok
  ;; XFS_DINODE_MAGIC        0x494e Short/Long Ok
  (let ((magic (slice4 buf 0))
        (result nil))
    (cond
      ((= magic 0x58444233) (setf result XDB3))
      ((= magic 0x58444433) (setf result XDD3))
      ((= 0x494e0000 (& magic 0x494e0000))
       ;; Long Inode:  0x494exxxx0302 Extents
       ;; Short Inode: 0x494exxxx0301 Local
       (if (and (= 0x0302 (slice2 buf 4))
                ;; some nodes claim extent but are type short
                (= 0x00 (slice1 buf 0xb0))) ;; FIXME (?) determine more accuratly
           (setf result DINL) ;; DINODE with fsblock extents
           (setf result DINS)) ;; false claim of extent node
       (when (= 0x0301 (slice2 buf 4))
         (setf result DINS))) ;; DINODE with direct Inodes
      (true (setf result NON)))
    result))

(define (readInode inode buf)
  ;; read a given inode into buf
  (let ((byteOffset (xfs_ino_to_bytes inode)))
    (seek DISK byteOffset)
    (read DISK buf (SB "blocksize"))))

(define (dins_t_node buf)
  ;; Process XFS Short Inode to Inode Lst
  ;; Return:
  ;; '((list inode name type uid gid) ...(list inode name type uid gid))
  ;; inode = #of inode
  ;; name  = fqn of dir or file-info
  ;; type  = 1 File   2 Dir
  ;; uid   = should be UID
  ;; gid   = should be GID
  (let ((inolength 0)
        (pointer 0xb0) ;; xfs inode list after uuid
        (inode 0)
        (parentino -1)
        (numchars -1)
        (name "")
        (type -1)
        (result '())
        (uid  (slice4 buf 8))
        (gid  (slice4 buf 12)))
    ;; Set inode number length 4 or 8 bytes
    ;; buf[0xb1] = xfs i8count
    ;; if buf[0xb1] == 0 -> 4byte inode numbers Else 8byte
    (if (= 0 (slice1 buf (+ pointer 0x01)))
        (setf inolength 4
              pointer 0xb6
              parentino (slice4 buf (- pointer inolength)))
        (setf inolength 8
              pointer 0xba
              parentino (slice8 buf (- pointer inolength))))
    ;; loop through content; dont go to the end
    (while (< pointer (- (SB "inodesize") 16))
    ;; (while (< pointer (- (length buf) 16 1))
      (setf numchars (slice1 buf pointer))
      (setf name (first (unpack (append "s" (string numchars))
                                (slice buf (+ pointer 3) numchars))))
      (setf type (slice1 buf (+ pointer numchars 3)))
      (if (= 8 inolength)
          (setf inode (slice8 buf (+ pointer numchars 4)))
          (setf inode (slice4 buf (+ pointer numchars 4))))
      (if (or (= XFS_FILE type) (= XFS_DIR type))
          (begin
            ;; (println "DINS PTR: " (format "0x%x" pointer) "  NC: " numchars " NAME:" name " type: " type)
            (push (list inode name type uid gid) result -1)
            (++ pointer (+ numchars 4 inolength)))
          (begin
            (++ pointer)))) ;; when type not OK, advance by one to sync again
    (unique result)))

(define (doFsblocks buf pointer)
  ;; DINL fsblock helper
  ;; Check if fsblocks in inode are some how consistent.
  ;; Won't probably catch every broken stuff.
  ;; Return:
  ;; (offset fsblock #blocks)
  ;; Non sensible blocks return: '(0 0 0), failure analyze above this func
  (let ((result '())
        (moffset (>> (& (slice4 buf (+ pointer 0x03)) 0x1ffff) 1))
        (mfsb (& (slice8 buf (+ pointer 0x06)) 0x01fffffffffffe))
        (mblocks  (& (slice4 buf (+ pointer 0x0c)) 0x1ffff))
        (noffset (>> (slice4 buf (+ pointer 0x0f 0x04)) 1))
        (nfsb (& (slice8 buf (+ pointer 0x0f 0x06 1)) 0x01fffffffffffe)))
    ;; (println "MFSB: " (format "%llx" mfsb))
    (if (!= 0 mblocks)
        (begin
          (cond
           ;; check for broken first so that anything is skipped
           ((or (and (not (= 0 (slice4 buf pointer))) ;; leaf ?
                     (!= mblocks noffset))
                (= 0 mfsb))
            ;; (println "nothing")
            (list 0 0 0))
           ((and (not (= 0 (slice4 buf pointer))) ;; broken fsblock
                 (= mblocks noffset))              ;; but offset = blocks -> OK
            ;; (println "broken: " (format "0x%llx " nfsb))
            (list moffset (- (>> nfsb 5) (* 8 (+ mblocks 1)))  mblocks))
           ((= 0 (slice4 buf pointer)) ;; normal block
            ;; (println "normal: " (format "0x%llx " mfsb))
            (list moffset (>> mfsb 5) mblocks))))
        (begin
          (list 0 0 0)))))

(define (dinl_t_node buf)
  ;; Process XFS Long Inode to Inode Lst
  ;; Return:
  ;; '((list inode name type uid gid) ... (list inode name type uid gid))
  ;; inode = #of inode
  ;; name  = fqn of dir or file-info
  ;; type  = 1 File   2 Dir
  ;; uid   = should be UID
  ;; gid   = should be GID
  (let ((pointer 0xb0)
        (uid (slice4 buf 8))
        (gid (slice4 buf 12))
        (fsblock 0)
        (blocks 0)
        (result '())
        (fsbresult '())
        (nodeType 0))
    ;; collect all fsblocks with num of blocks, upto first leaf block
    ;; v5 starts @0xb0
    (while (< pointer (- (SB "inodesize") 32)) ;; only up to last 16byte row
    ;; (while (< pointer (- (length buf) 32 1)) ;; only up to last 16byte row
      (push (doFsblocks buf pointer) fsbresult -1)
      (++ pointer 16))
    ;; fsbresult = (offset fsblock #blocks)
    (dolist (fsblockLst (sort (unique fsbresult) <)) ;; loop over fsblocks
      ;; (println "FSBLOCKLST: " fsblockLst)
      (if (and (!= 0 (nth 1 fsblockLst)) ;; and read them
               (!= 0 (last fsblockLst)))
          (begin
            (seek DISK (xfs_fsb_to_bytes (nth 1 fsblockLst)))
            (when (= (* (SB "blocksize")
                        (last fsblockLst)) ;; how many bytes
                     (readFsblock fsblockLst buf))
              (setf nodeType (getInodeType buf)) ;; get xfs node type

              ;; No default action. if it fails than do nothing.
              (cond
               ((= nodeType XDB3)
                ;; (println "XDB3")
                ;; (readFsblock fsblockLst buf) ;; get XDB3 block
                (extend result (xdb3_t buf))) ;; work on it
               ((= nodeType XDD3)
                ;; (readFsblock fsblockLst buf) ;; get XDD3 block
                ;; (println "XDD3")
                (extend result (xdd3_t buf))) ;; work on it
              ((= nodeType DINS) ;; Short Dinode
               ;; (println "DINS")
               (extend result (dins_t buf)))
              ((= nodeType DINL) ;; Long Dinode
               ;; (println "DINL")
               (extend result (dinl_t buf))))))
          (begin
            (push (list 0 "" 0 0 0) result -1))))
    (unique result)))

(define (xdb3_t_node buf)
  ;; XFS_DIR3_BLOCK_MAGIC    0x58444233
  ;; Process XFS XDB3 (XFS DIR3 BLOCK) to Inode Lst
  ;; Return:
  ;; '((list inode name type uid gid) ... (list inode name type uid gid))
  ;; inode = #of inode
  ;; name  = fqn of dir or file-info
  ;; type  = 1 File   2 Dir
  ;; uid   = placeholder for DINODE routines
  ;; gid   = placeholder for DINODE routines
  ;; uid and gid are from parent inode !
  (let ((pointer 0x40)
        (inode 0)
        (typus 0)
        (uid 0) ;; UIDs and GIDs only in DINODEs
        (gid 0)
        (numchars 0)
        (result '()))

    ;; check if it is a "broken" XDD3 structure with no
    ;; "." and ".." entry @0x40.
    ;; Could happen with multiple fsblocks within DINL.
    (when (= 0x012e02 (& 0x00ffffff (slice4 buf 0x47))) ;; "."
      (setf pointer 0x50))
    (when (= 0x022e2e02 (slice4 buf 0x58)) ;; ".."
      (setf pointer 0x60))

    ;; loop through content; don't go to the end
    ;; because we read ahead.
    (while (< pointer (- (length buf) 1 8))
      ;; (print "POINTER: " (format "0x%x  %d " pointer typus))
      (setf inode     (slice8 buf pointer))
      (setf numchars  (slice1 buf (+ pointer 8)))
      (if (< (+ pointer 8 (abs numchars) 1) (- (length buf) 1))
          (begin
            (setf typus (slice1 buf (+ pointer 8 (abs numchars) 1))) ;; check if pointer + numchars == valid type
            (cond ;; test if we got a valid inode
             ((and (= 0 numchars) (< inode 0)) ;; freetag (?)
              ;; (println "cond1 " (format "0x%x  " pointer)))
              (setf pointer (padLongInodes (+ 7 pointer))))

             ((and (!= numchars 0)
                   (> inode 0)
                   (> (>> inode 3) (SB "dblocks"))) ;; illegal inode
              ;; (println "cond2")
              (setf pointer (padLongInodes (+ 7 pointer))))

             ((and (!= numchars 0) (< inode 0)) ;; freetag node with numchars>0
              ;; advance pointer:
              ;; pointer = pad(pointer + inode + (#numchars) + numchars + type + 1[next start])
              ;; (println "cond3")
              (setf pointer (padLongInodes (+ 7 pointer)))) ;; next 8bytes block

             ((and (!= numchars 0) (> inode 0) ;; this seems to be a valid entry
                   (< (>> inode 3) (SB "dblocks"))
                   (<= typus 2) ;; only XFS_DIR and XFS_FILES
                   (>= typus 1)
                   (< (+ numchars pointer 9) (- (length buf) 1))) ;; dont go to far
              (let ((name (first (unpack (append "s" (string numchars))
                                         (slice buf (+ pointer 9) numchars)))))
                ;;     (type (slice1 buf (+ pointer 9 numchars))))
                ;; (when (and (< type 3) (> type 0) (> (getInodeType buf) 0))
                ;; (println "cond4 " name)
                (push (list inode name typus uid gid) result -1)
                (setf pointer (padLongInodes (+ 8 1 3 numchars pointer)))))
             (true ;; anything else carry on
              ;; (println "Leftover")
              (setf pointer (padLongInodes (+ pointer 7))))))
          (begin
            (setf pointer (padLongInodes (+ pointer 7))))))
    (unique result)))

(define (xdd3_t_node buf)
  ;; XFS_DIR3_DATA_MAGIC    0x58444433
  ;; Process XFS XDD3 (XFS DIR DATA) to Inode Lst
  ;; Return:
  ;; '((list inode name type uid gid) ... (list inode name type uid gid))
  ;; inode = #of inode
  ;; name  = fqn of dir or file-info
  ;; type  = 1 File   2 Dir
  ;; uid   = placeholder for DINODE routines
  ;; gid   = placeholder for DINODE routines
  ;; uid and gid are from parent inode !
  (let ((pointer 0x40)
        (inode 0)
        (typus 0)
        (uid 0) ;; UIDs and GIDs only in DINODEs
        (gid 0)
        (numchars 0)
        (result '()))

    ;; check if it is a "broken" XDD3 structure with no
    ;; "." and ".." entry @0x40.
    ;; Could happen with multiple fsblocks within DINL.
    (when (= 0x012e02 (& 0x00ffffff (slice4 buf 0x47))) ;; "."
      (setf pointer 0x50))
    (when (= 0x022e2e02 (slice4 buf 0x58)) ;; ".."
      (setf pointer 0x60))

    ;; loop through content; don't go to the end
    ;; because we read ahead.
    (while (< pointer (- (length buf) 8 1))
      (setf inode     (slice8 buf pointer))
      (setf numchars  (slice1 buf (+ pointer 8)))
      (if (< (+ pointer 8 (abs numchars) 1) (- (length buf) 1))
          (begin
            (setf typus (slice1 buf (+ pointer 8 (abs numchars) 1))) ;; check if pointer + numchars == valid type
            ;; (print "PTR: " (format "0x%x  " pointer))
            (cond ;; test if we got a valid inode
             ((and (= 0 numchars) (< inode 0)) ;; freetag (?)
              ;; (println "cond1")
              (setf pointer (padLongInodes (+ 7 pointer))))

             ((and (!= numchars 0)
                   (> inode 0)
                   (> (>> inode 3) (SB "dblocks"))) ;; illegal inode
              ;; (println "cond2")
              (setf pointer (padLongInodes (+ 7 pointer))))

             ((and (> (abs numchars) 0) (< inode 0)) ;; freetag node with numchars>0
              ;; advance pointer:
              ;; pointer = pad(pointer + inode + (#numchars) + numchars + type + 1[next start])
              ;; (println "cond3")
              (setf pointer (padLongInodes (+ 7 pointer))))

             ((and (!= numchars 0) (> inode 0) ;; this seems to be a valid entry
                   (< (>> inode 3) (SB "dblocks"))
                   (<= typus 2) ;; only XFS_DIR and XFS_FILES
                   (>= typus 1)
                   (< (+ numchars pointer 9) (length buf))) ;; dont go to far
              (let ((name (first (unpack (append "s" (string numchars))
                                         (slice buf (+ pointer 9) numchars)))))
                ;;           (type (slice1 buf (+ pointer 9 numchars))))
                ;; (println "cond4 " name)
                ;; (when (and (< type 3) (> type 0) (> (getInodeType buf) 0))
                (push (list inode name typus uid gid) result -1)
                (setf pointer (padLongInodes (+ 8 1 3 numchars pointer)))))
             (true ;; anything else carry on
              ;; (println "Leftover")
              (setf pointer (padLongInodes (+ 7 pointer))))))
          (begin
            (setf pointer (padLongInodes (+ 7 pointer))))))
    (unique result)))

(define (restoreFileLong inode name buf)
  ;; inode = #of inode
  ;; name  = fqn of dir or file-info
  ;; buf   = binary of files inode entry
  (let ((pointer 0xb0)
        ;; (uid (slice4 buf 8))
        ;; (gid (slice4 buf 12))
        (fsbresult '())
        (of (open name "write"))) ;; open outfile

    (when of ;; only do it when of is writable

      (readInode inode buf) ;; Read files main inode

      ;; collect all fsblocks with num of blocks, upto first leaf block
      ;; v5 starts @0xb0
      (while (< pointer (- (SB "inodesize") 32)) ;; only up to last 16byte row
        (push (doFsblocks buf pointer) fsbresult -1)
        (++ pointer 16)) ;; fsbresult = '((offset byteOffsetOnDisk #blocks) ....)

      (dolist (fsbLst (unique fsbresult)) ;; loop over blocks
        (when (and (!= 0 (nth 1 fsbLst)) ;; and read them
                   (!= 0 (last fsbLst)))
          (readFsblock fsbLst buf) ;; read file blocks
          (when (> (length buf) 0)
            (write of buf)))) ;; write em
      (close of))))

;; xfs block types entry calls
;; TODO: remove this block. Not really necessary.
(define (xdb3_t buf)
  ;;  (println "XDB3")
  (xdb3_t_node buf))
(define (xdd3_t buf)
  ;;  (println "XDD3")
  (xdd3_t_node buf))
(define (dins_t buf)
   ;; (println "DINS")
  (dins_t_node buf))
(define (dinl_t buf)
   ;; (println "DINL")
  ;; result is operation on FSBLOCK list inside.
  (dinl_t_node buf))

####################################################
#           MAIN
####################################################
;; (main-args) = "newlisp" "-c" "progr" "param1" "param2" ....
;; (println (main-args))

(when (not (main-args 3))
  (println "Usage: " (main-args 2) " /dev/to/scan  [startinode]")
  (exit))

(setf DISK (open (main-args 3) "read"))
(when (not DISK)
  (println "Could not open partition.")
  (exit))
(global 'DISK)

(readSuperblock) ;; Get XFS partition Superblock
;; (printHash (append "Superblock " (main-args 3) ":")
;;            SB)

(when (main-args 4)
  ;; get start inode if passed on cmd line
    (SB "rootino" (int (main-args 4))))

(setf TARGETDIR "./")
(when (main-args 5)
  ;; directory where to save.
  ;; Create beforehand
  (setf TARGETDIR (main-args 5)))
(global 'TARGETDIR)

(define (readRoot inode buf)
  ;; read start or root inode and
  ;; create inital inodelst for recursion.
  (readInode inode buf)
  ;; determine type from global buffer
  (let ((nodeType (getInodeType buf)))
    ;; (println "NT: " nodeType)
    (cond
     ;; return type: '((ino name type uid gid)...(ino name type uid gid))
     ;; i.e. ((515 "home" 2 0 0) (96934490635 "data" 2 0 0))
     ((= nodeType XDB3)
      (xdb3_t buf))
     ((= nodeType XDD3)
      (xdd3_t buf))
     ((= nodeType DINS)
      (dins_t buf))
     ((= nodeType DINL)
      (dinl_t buf)))))

(define (getInodesFromInode inodelst dirname buf)
  ;; Recurse over XFS node Tree
  ;; Main entry for RECURSIVE RESTORATION process
  ;;
  ;; inodelst = '((ino name type uid gid)...(ino name type uid gid))
  ;; dirname = list of dirname elements '("home" "user")
  (let ((fileFQN "")
        (dirFQN ""))
    (when (or (not (empty? inodelst)) ;; funcs should retrurn '() on fail
              (not nil))
      (when (< RECCOUNTER 0) ;; limit recursion for runaway effect
        (println "Depth Limit " RECCOUNTER)
        (exit))
      (dolist (lst inodelst)
        ;; (when (and (!= "nabiz" (nth 1 lst))
        ;;            (!= "rusousse" (nth 1 lst)))
          ;; ((515 "home" 2 0 0) (96934490635 "data" 2 0 0))
          ;; Failure list (0 0 0 0 0 0)
          ;; (println "LST: " lst)
          ;; We memoize dir inodes to prevent circular calls
          (cond
           ((and (= 2 (nth 2 lst)) ;; XFS_DIR
                 (not (XFSNODES (string (first lst))))) ;; check if we got it already
            ;; memoize the dir inodes to prevent large circular runs
            (XFSNODES (string (first lst)) 1)
            (push (nth 1 lst) dirname -1)
            ;; remove nonsense chars from dirname
            (setf dirFQN (replace FORBIDCHARS (join dirname "/") "" 0x10000))
            (when (and CREATION
                       (not (directory? dirFQN))) ;; only do it when it not exists.
              (make-dir dirFQN))
            (println "DIR:" (first lst) ":" (getInodeType buf) ":" dirFQN)
            (-- RECCOUNTER)
            (readInode (first lst) buf) ;; read buf inode points to
            (let ((nodeType (getInodeType buf)))
              (cond
               ;; return type: '((ino name type uid gid)...(ino name type uid gid))
               ;; i.e. ((515 "home" 2 0 0) (96934490635 "data" 2 0 0))
               ((= nodeType XDB3) (getInodesFromInode (xdb3_t buf) dirname buf))
               ((= nodeType XDD3) (getInodesFromInode (xdd3_t buf) dirname buf))
               ((= nodeType DINS) (getInodesFromInode (dins_t buf) dirname buf))
               ((= nodeType DINL) (getInodesFromInode (dinl_t buf) dirname buf)))
              (pop dirname -1)
              (++ RECCOUNTER)))
           ((= 1 (nth 2 lst)) ;; XFS_FILES
            (setf filename (append (join dirname "/") "/" (nth 1 lst)))
            (replace FORBIDCHARS filename "" 0x10000) ;; only allow good chars in filename
            (println "FIL:" (first lst) ":" filename)
            (when (and CREATION
                       (not (file? filename)))
              (restoreFileLong (first lst) filename buf)))
           ((= 0 (nth 2 lst))
            (println "NON: No Dir or FIL "))))))) ;; just something so we can calc the known misses

;; initialize first inode Lst
(setf initLst (readRoot (SB "rootino") GBUF))
;; (println "INIT: " initLst)
;; (exit)

;; do it all recursively
(getInodesFromInode initLst (parse TARGETDIR "/") GBUF)

(close DISK)
(exit)
