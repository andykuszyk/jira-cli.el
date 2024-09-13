(add-to-list 'load-path "./")
(require 'jira-cli)

(ert-deftest jira-cli--parse-issue-reference-test ()
  (should (string=
	   (jira-cli--parse-issue-reference "Story	ABC-1127	Patching: ECS AMI				In Progress")
	   "ABC-1127"))
  (should (string=
	   (jira-cli--parse-issue-reference "TYPE	KEY		SUMMARY						STATUS")
	   nil))
  (should (string=
	   (jira-cli--parse-issue-reference "Epic	ABC-990		Compute - ECS Hardware Instance Modernisation	In Progress")
	   "ABC-990")))
(provide 'jira-cli-tests)
