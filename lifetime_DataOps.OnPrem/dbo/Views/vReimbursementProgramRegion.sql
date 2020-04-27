

CREATE VIEW dbo.vReimbursementProgramRegion
AS
SELECT     ReimbursementProgramRegionID, ReimbursementProgramID, ValRegionID, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.ReimbursementProgramRegion WITH (NoLock)


