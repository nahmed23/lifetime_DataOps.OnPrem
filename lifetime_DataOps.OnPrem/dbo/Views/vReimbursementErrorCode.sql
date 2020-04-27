

CREATE VIEW dbo.vReimbursementErrorCode
AS
SELECT     ReimbursementErrorCodeID, ReimbursementProgramID, ErrorCode, ErrorDescription, InsertedDateTime, UpdatedDateTime
FROM         MMS.dbo.ReimbursementErrorCode WITH (NoLock)



