


CREATE VIEW dbo.vReimbursementErrorAction
AS
SELECT     ReimbursementErrorActionID, ReimbursementErrorCodeID, ErrorActionRule, ErrorActionRuleSequence, ValMembershipMessageTypeID,MembershipMessageComments,ValReimbursementTerminationReasonID,OpenMessageFlag
FROM         MMS.dbo.ReimbursementErrorAction WITH (NoLock)




