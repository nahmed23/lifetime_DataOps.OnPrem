CREATE VIEW dbo.vEmailTemplate AS 
SELECT EmailTemplateID,EmailFromAddress,EmailSubject,EmailTemplatePath
FROM MMS.dbo.EmailTemplate WITH(NOLOCK)
