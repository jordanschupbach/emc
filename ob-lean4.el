;;; ob-lean4.el --- Org-Babel support for Lean 4 -*- lexical-binding: t; -*-

(require 'org-macs)
(org-assert-version)

(require 'ob)
(require 'ob-eval)

(defvar org-babel-tangle-lang-exts)
(add-to-list 'org-babel-tangle-lang-exts '("lean4" . "lean"))

(defgroup org-babel-lean4 nil
  "Org Babel support for Lean 4."
  :group 'org-babel)

(defcustom org-babel-lean4-command "lean"
  "Name of the command used to execute Lean 4 source code."
  :group 'org-babel-lean4
  :type 'string)

(defcustom org-babel-lean4-hline-to "none"
  "Replace hlines in incoming tables with this when translating to Lean.
Lean has no untyped null value; this is a best-effort placeholder and
may fail to elaborate depending on the target type."
  :group 'org-babel-lean4
  :type 'string)

(defcustom org-babel-lean4-nil-to 'hline
  "Replace nil in Lean results with this before returning to Org."
  :group 'org-babel-lean4
  :type 'symbol)

(defvar org-babel-default-header-args:lean4
  '((:results . "output")
    (:exports . "results"))
  "Default header arguments for Lean 4 source blocks.")

(defun org-babel-execute:lean4 (body params)
  "Execute Lean 4 BODY according to PARAMS.
This function is called by `org-babel-execute-src-block'."
  (let* ((result-params (cdr (assq :result-params params)))
         (flags (cdr (assq :flags params)))
         (cmdline (cdr (assq :cmdline params)))
         (src-file (org-babel-temp-file "ob-lean4-" ".lean"))
         (full-body (org-babel-expand-body:lean4 body params))
         (use-run (org-babel-lean4--has-main-p full-body))
         (flags-str (mapconcat #'identity
                                (delq nil (if (listp flags) flags (list flags)))
                                " "))
         (command (concat org-babel-lean4-command
                           (if use-run " --run" "")
                           (if (string-empty-p flags-str) "" (concat " " flags-str))
                           " " (org-babel-process-file-name src-file)
                           (if (and use-run cmdline) (concat " " cmdline) ""))))
    (with-temp-file src-file
      (insert full-body))
    (let ((results (org-babel-eval command "")))
      (org-babel-reassemble-table
       (org-babel-result-cond result-params
         results
         (org-babel-lean4-table-or-string results))
       (org-babel-pick-name (cdr (assq :colname-names params))
                            (cdr (assq :colnames params)))
       (org-babel-pick-name (cdr (assq :rowname-names params))
                            (cdr (assq :rownames params)))))))

(defun org-babel-prep-session:lean4 (_session _params)
  "Prepare a Lean 4 session.

Org Babel Lean 4 blocks currently do not support sessions."
  (error "Org Babel Lean 4 does not support sessions"))

(defun org-babel-expand-body:lean4 (body params)
  "Expand Lean 4 BODY according to PARAMS."
  (let* ((imports (cdr (assq :imports params)))
         (imports (if (stringp imports) (split-string imports) imports))
         (var-lines (org-babel-variable-assignments:lean4 params)))
    (mapconcat
     #'identity
     (delq
      nil
      (list
       (when imports
         (mapconcat (lambda (imp) (format "import %s" imp)) imports "\n"))
       (when var-lines
         (mapconcat #'identity var-lines "\n"))
       (org-babel-chomp body)))
     "\n\n")))

(defun org-babel-lean4--has-main-p (body)
  "Return non-nil if BODY defines `main', requiring `lean --run' to execute it."
  (string-match-p "\\(?:\\`\\|[[:space:]\n\r]\\)def[[:space:]]+main\\_>" body))

(defun org-babel-variable-assignments:lean4 (params)
  "Return a list of Lean 4 `def' statements assigning variables from PARAMS."
  (mapcar
   (lambda (pair)
     (format "def %s := %s" (car pair) (org-babel-lean4-var-to-lean (cdr pair))))
   (org-babel--get-vars params)))

(defun org-babel-lean4-var-to-lean (var)
  "Convert VAR into a string of Lean 4 source code representing VAR."
  (cond
   ((eq var 'hline) org-babel-lean4-hline-to)
   ((null var) org-babel-lean4-hline-to)
   ((eq var t) "true")
   ((numberp var) (number-to-string var))
   ((stringp var) (org-babel-lean4--quote-string var))
   ((listp var)
    (concat "[" (mapconcat #'org-babel-lean4-var-to-lean var ", ") "]"))
   (t (org-babel-lean4--quote-string (format "%s" var)))))

(defun org-babel-lean4--quote-string (s)
  (concat "\""
          (replace-regexp-in-string
           "[\"\\\\]"
           (lambda (m) (concat "\\\\" m))
           s
           t t)
          "\""))

(defun org-babel-lean4-table-or-string (results)
  "Convert RESULTS into an appropriate elisp value.
If RESULTS look like an Org table, return it as a table.  Otherwise
return a string."
  (let ((res (org-babel-script-escape results)))
    (if (listp res)
        (mapcar (lambda (el) (if (not el) org-babel-lean4-nil-to el)) res)
      res)))

(provide 'ob-lean4)

;;; ob-lean4.el ends here
