CREATE VIEW dbo.vEmailTemplateRule AS 
SELECT EmailTemplateRuleID,EmailEventID,ProductID,EmailTemplateID
FROM MMS.dbo.EmailTemplateRule WITH(NOLOCK)
