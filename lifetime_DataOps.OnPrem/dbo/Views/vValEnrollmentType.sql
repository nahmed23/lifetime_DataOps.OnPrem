
CREATE VIEW dbo.vValEnrollmentType AS 
SELECT ValEnrollmentTypeID,Description,SortOrder
FROM MMS.dbo.ValEnrollmentType WITH (NoLock)

