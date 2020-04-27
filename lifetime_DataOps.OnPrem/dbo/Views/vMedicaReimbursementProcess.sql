
CREATE VIEW dbo.vMedicaReimbursementProcess AS 
SELECT MedicaReimbursementProcessID,TranDate,ReferenceCode,Comment,StartDate,EndDate,IsRunningFlag
FROM MMS.dbo.MedicaReimbursementProcess WITH (NoLock)

