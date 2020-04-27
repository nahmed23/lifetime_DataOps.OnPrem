
CREATE  VIEW dbo.vTranPayment
AS
SELECT 	p.PaymentID,
       	p.ValPaymentTypeID,
			vpt.Description,
			p.PaymentAmount,
			p.ApprovalCode,
			p.MMSTranID,
			p.TipAmount,
			pa.ExpirationDate,
       	pa.AccountNumber,	
			pa.RoutingNumber,
			pa.Name,
			pa.BankName,
			pa.MaskedAccountNumber,
			pa.EncryptedAccountNumber
FROM   	vPayment p 

JOIN   	vValPaymentType vpt 
	ON 	p.ValPaymentTypeID = vpt.ValPaymentTypeID

LEFT   OUTER JOIN vPaymentAccount pa 
	ON p.PaymentID = pa.PaymentID


