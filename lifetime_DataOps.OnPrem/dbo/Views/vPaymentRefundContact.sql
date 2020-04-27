CREATE VIEW dbo.vPaymentRefundContact AS 
SELECT PaymentRefundContactID,FirstName,LastName,MiddleInit,PhoneAreaCode,PhoneNumber,AddressLine1,AddressLine2,City,Zip,ValCountryID,ValStateID,PaymentRefundID
FROM MMS_Archive.dbo.PaymentRefundContact WITH(NOLOCK)
