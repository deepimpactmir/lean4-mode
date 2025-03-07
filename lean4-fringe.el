;;; lean4-fringe.el --- Show Lean processing progress in the editor fringe -*- lexical-binding: t; -*-
;;
;; Copyright (c) 2016 Microsoft Corporation. All rights reserved.
;; Released under Apache 2.0 license as described in the file LICENSE.
;;
;; Authors: Gabriel Ebner, Sebastian Ullrich
;; SPDX-License-Identifier: Apache-2.0

;;; License:

;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at:
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

;;; Commentary:
;;
;; Show Lean processing progress in the editor fringe
;;
;;; Code:

(require 'lean4-settings)
(require 'lsp-mode)
(require 'lsp-protocol)

(eval-when-compile
  (lsp-interface
    (lean:LeanFileProgressProcessingInfo (:range :kind) nil)
    (lean:LeanFileProgressParams (:textDocument :processing) nil)))

(defvar-local lean4-fringe-delay-timer nil)

(lsp-defun lean4-fringe-region ((&lean:LeanFileProgressProcessingInfo :range))
  (lsp--range-to-region range))

(defface lean4-fringe-face
  nil
  "Face to highlight Lean file progress."
  :group 'lean4)

(if (fboundp 'define-fringe-bitmap)
  (define-fringe-bitmap 'lean4-fringe-fringe-bitmap
    (vector) 16 8))

(defface lean4-fringe-fringe-processing-face
  '((((class color) (background light))
     :background "chocolate1")
    (((class color) (background dark))
     :background "navajo white")
    (t :inverse-video t))
  "Face to highlight the fringe of Lean file processing progress."
  :group 'lean)

(defface lean4-fringe-fringe-fatal-error-face
  '((((class color) (background light))
     :background "red")
    (((class color) (background dark))
     :background "red")
    (t :inverse-video t))
  "Face to highlight the fringe of Lean file fatal errors."
  :group 'lean)

(lsp-defun lean4-fringe-fringe-face ((&lean:LeanFileProgressProcessingInfo :kind))
  (cond
   ((eq kind 1) 'lean4-fringe-fringe-processing-face)
   (t 'lean4-fringe-fringe-fatal-error-face)))

(defvar-local lean4-fringe-data nil)

(defun lean4-fringe-update-progress-overlays ()
  "Update 'processing' bars in the current buffer."
  (dolist (ov (flatten-tree (overlay-lists)))
    (when (eq (overlay-get ov 'face) 'lean4-fringe-face)
      (delete-overlay ov)))
  (when lean4-show-file-progress
    (seq-doseq (item lean4-fringe-data)
      (let* ((reg (lean4-fringe-region item))
             (ov (make-overlay (car reg) (cdr reg))))
        (overlay-put ov 'face 'lean4-fringe-face)
        (overlay-put ov 'line-prefix
                     (propertize " " 'display
                                 `(left-fringe lean4-fringe-fringe-bitmap ,(lean4-fringe-fringe-face item))))
        (overlay-put ov 'help-echo (format "processing..."))))))

(defvar-local lean4-fringe-delay-timer nil)

(lsp-defun lean4-fringe-update (workspace (&lean:LeanFileProgressParams :processing :text-document (&VersionedTextDocumentIdentifier :uri)))
  (dolist (buf (lsp--workspace-buffers workspace))
    (lsp-with-current-buffer buf
      (when (equal (lsp--buffer-uri) uri)
        (setq lean4-fringe-data processing)
        (save-match-data
          (when (not (memq lean4-fringe-delay-timer timer-list))
            (setq lean4-fringe-delay-timer
                  (run-at-time "300 milliseconds" nil
                               (lambda (buf)
                                 (with-current-buffer buf
                                   (lean4-fringe-update-progress-overlays)))
                               (current-buffer)))))))))

(provide 'lean4-fringe)
;;; lean4-fringe.el ends here
