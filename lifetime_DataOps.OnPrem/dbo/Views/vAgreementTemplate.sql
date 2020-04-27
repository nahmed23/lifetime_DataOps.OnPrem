


CREATE VIEW dbo.vAgreementTemplate
AS
SELECT AgreementTemplateID, AgreementID, TemplateID, TemplateOrder
FROM MMS.dbo.AgreementTemplate With (NOLOCK)


