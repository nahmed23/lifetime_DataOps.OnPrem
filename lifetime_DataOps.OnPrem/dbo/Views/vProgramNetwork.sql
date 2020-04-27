CREATE VIEW dbo.vProgramNetwork AS 
SELECT ProgramNetworkID,ProgramNetworkTypeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProgramNetwork WITH(NOLOCK)
