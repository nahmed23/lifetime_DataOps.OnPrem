
CREATE VIEW dbo.vValMedicaProgram AS 
SELECT ValMedicaProgramID,Description,SortOrder,ReimbursementAmount,PrecedenceFlag,TaxFlag
FROM MMS.dbo.ValMedicaProgram WITH (NOLOCK)

