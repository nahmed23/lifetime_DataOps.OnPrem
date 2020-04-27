/*
 ***************************************************************************************************
    AUTHOR				: Pradeep Kumar N
	CREATE DATE			: 16 August 2018
	TICKET NO		    : 4490
    DESCRIPTION			: Add EFTTokenRequest to production view in Report_MMS and MMS_SystemTest


	MODIFICATION HISTORY:
	Date					Author				Comment
	------				-------				--------
	
******************************************************************************************************
*/ 
CREATE VIEW dbo.vEFTTokenRequest
AS 
SELECT 
EFTTokenRequestID,
Job_Task_ID,
TableName,
PrimaryKey,
CAST(NULL AS VARBINARY(48)) AS EncryptedAccountNumber,
MaskedAccountNumber64,
ValPaymentTypeID,
InsertedDateTime,
UpdatedDateTime,
Token,
ResponseReasonCode,
status
FROM [MMS_Archive].dbo.EFTTokenRequest