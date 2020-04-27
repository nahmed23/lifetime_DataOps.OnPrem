
CREATE VIEW dbo.vValContractType AS 
SELECT ValContractTypeID,Description,SortOrder,XMLBuilderClass,MemberAgreementFlag,ActiveFlag,PreSaveFlag
FROM MMS.dbo.ValContractType WITH(NOLOCK)

