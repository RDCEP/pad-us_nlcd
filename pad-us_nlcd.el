(require 'org)
(require 'org-exp)
(require 'org-install)
(require 'ess-site)

(org-babel-do-load-languages
 'org-babel-load-languages
 (quote
  ((emacs-lisp . t) 
   (R . t)
   (sh . t))))

(let ((org-confirm-babel-evaluate nil)
      (org-src-preserve-indentation 'true)
      (ess-ask-for-ess-directory nil))
  (progn (find-file "pad-us_nlcd.org")
         (org-babel-tangle)))
