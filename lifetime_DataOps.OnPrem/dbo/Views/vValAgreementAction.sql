CREATE VIEW dbo.vValAgreementAction AS 
SELECT ValAgreementActionID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValAgreementAction WITH(NOLOCK)
