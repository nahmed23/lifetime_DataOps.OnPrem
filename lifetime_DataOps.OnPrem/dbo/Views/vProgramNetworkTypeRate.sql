CREATE VIEW dbo.vProgramNetworkTypeRate AS 
SELECT ProgramNetworkTypeRateID,ProgramNetworkTypeID,NetworkCount,Rate,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProgramNetworkTypeRate WITH(NOLOCK)
