


CREATE VIEW [dbo].[vPOSDrawerDetail]
	(DrawerStatusDescription,CloseDateTime,RegionDescription,ClubName,DrawerActivityID,PostDateTime,MemberID,FirstName,LastName,TranVoidedID,ReceiptNumber,EmployeeID,DomainName,TranTypeDescription,DeptDescription,Quantity,Amount,Tax,Total,Sort,Desc1,Desc2,Record,ChangeRendered,ReceiptComment,TipAmount,IssuanceAmount,CardOnFileFlag)
AS
------ Returns the Sale side of a sale transaction
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL8.MemberID, AL8.FirstName, AL8.LastName, AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL12.Description, AL10.Quantity, AL10.ItemAmount, AL10.ItemSalesTax, AL10.ItemAmount + AL10.ItemSalesTax, STR ( (AL1.MMSTranID/AL1.MMSTranID), 1, 0 ), AL11.Description, /*AL11.Description*/ "", AL10.TranItemID, AL1.ChangeRendered, AL1.ReceiptComment , 0.00 as TipAmount, AL17.IssuanceAmount, Null as CardOnFileFlag
FROM dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) LEFT OUTER JOIN dbo.vTranItem AL10 ON (AL1.MMSTranID=AL10.MMSTranID) LEFT OUTER JOIN dbo.vProduct AL11 ON (AL10.ProductID=AL11.ProductID) LEFT OUTER JOIN dbo.vDepartment AL12 ON (AL11.DepartmentID=AL12.DepartmentID) LEFT OUTER JOIN (select distinct TranItemID, IssuanceAmount from dbo.vTranItemGiftCardIssuance) AL17 ON (AL17.TranItemID=AL10.TranItemID)
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description='Sale')

UNION
---- Returns Payment transactions
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL8.MemberID, AL8.FirstName, AL8.LastName, AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL14.Description, AL13.PaymentID, AL13.PaymentAmount, AL13.PaymentAmount, AL13.PaymentAmount, STR ((4* (AL1.MMSTranID/AL1.MMSTranID)), 1, 0 ), AL14.Description, AL13.ApprovalCode, AL13.PaymentID, AL1.ChangeRendered, AL1.ReceiptComment, AL13.TipAmount, 0.00 as IssuanceAmount
, AL18.CardOnFileFlag
FROM dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) LEFT OUTER JOIN dbo.vPayment AL13 ON (AL1.MMSTranID=AL13.MMSTranID) LEFT OUTER JOIN dbo.vValPaymentType AL14 ON (AL13.ValPaymentTypeID=AL14.ValPaymentTypeID) 
LEFT OUTER JOIN dbo.vPTCreditCardTransaction AL18 ON (AL18.PaymentID = AL13.PaymentID)
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description='Payment') 

UNION  
---- Returns the payment side of a sale transaction
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL1.MemberID, AL8.FirstName, AL8.LastName, AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL14.Description, AL13.PaymentID, AL13.PaymentAmount, AL13.PaymentAmount, AL13.PaymentAmount, STR ((2*( AL1.MMSTranID/AL1.MMSTranID)), 1, 0 ), AL14.Description, AL13.ApprovalCode, AL13.PaymentID, CASE WHEN AL1.TranEditedFlag =1 THEN 0 ELSE AL1.ChangeRendered END ChangeRendered, AL1.ReceiptComment, AL13.TipAmount, 0.00 as IssuanceAmount  
, AL18.CardOnFileFlag
FROM dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) LEFT OUTER JOIN dbo.vPayment AL13 ON (AL1.MMSTranID=AL13.MMSTranID) LEFT OUTER JOIN dbo.vValPaymentType AL14 ON (AL13.ValPaymentTypeID=AL14.ValPaymentTypeID) 
LEFT OUTER JOIN dbo.vPTCreditCardTransaction AL18 ON (AL18.PaymentID = AL13.PaymentID)
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description='Sale') 

UNION  
---- Returns Charge transactions
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL1.MemberID, AL8.FirstName, AL8.LastName, AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL12.Description, AL10.Quantity, AL10.ItemAmount, AL10.ItemSalesTax, (AL10.ItemAmount) + (AL10.ItemSalesTax), STR ( (3*(AL1.MMSTranID/AL1.MMSTranID)), 1, 0 ), AL11.Description, /*AL11.Description*/ "", AL10.TranItemID, AL1.ChangeRendered , AL1.ReceiptComment, 0.00 as TipAmount, AL17.IssuanceAmount, null as CardOnFileFlag
FROM dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) LEFT OUTER JOIN dbo.vTranItem AL10 ON (AL1.MMSTranID=AL10.MMSTranID) LEFT OUTER JOIN dbo.vProduct AL11 ON (AL10.ProductID=AL11.ProductID) LEFT OUTER JOIN dbo.vDepartment AL12 ON (AL11.DepartmentID=AL12.DepartmentID) LEFT OUTER JOIN (select distinct TranItemID, IssuanceAmount from dbo.vTranItemGiftCardIssuance) AL17 ON (AL17.TranItemID=AL10.TranItemID)
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description='Charge') 


UNION 
------ returns "no Sale" drawer activity 
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL3.AuditDateTime, AL3.EmployeeOneID, AL15.Description, AL15.Description, AL3.DrawerActivityID, AL5.Description, AL3.EmployeeOneID, AL6.DomainNamePrefix, AL15.Description, AL15.Description, AL3.Amount, AL3.Amount, AL3.Amount, AL3.Amount, STR ( (6*(AL2.DrawerActivityID/AL2.DrawerActivityID)), 1, 0 ), AL15.Description, /*AL15.Description*/ "", AL3.DrawerAuditID, 0.00 as ChangeRendered , "", 0.00 as TipAmount, 0.00 as IssuanceAmount, null as CardOnFileFlag 
FROM dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vDrawerActivity AL2 LEFT OUTER JOIN dbo.vDrawerAudit AL3 ON (AL3.DrawerActivityID=AL2.DrawerActivityID) LEFT OUTER JOIN dbo.vValDrawerAuditType AL15 ON (AL3.ValDrawerAuditTypeID=AL15.ValDrawerAuditTypeID) 
WHERE (AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID) 

UNION  
---- Returns Adjustment transactions
SELECT AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL1.MemberID, AL8.FirstName, AL8.LastName, AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL12.Description, AL10.Quantity, AL10.ItemAmount, AL10.ItemSalesTax, AL1.POSAmount + AL1.TranAmount, STR ( (5*(AL1.MMSTranID/AL1.MMSTranID)), 1, 0 ), AL16.Description, /*AL16.Description*/ "", AL1.MMSTranID, AL1.ChangeRendered , AL1.ReceiptComment, 0.00 as TipAmount, AL17.IssuanceAmount, null as CardOnFileFlag
FROM dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) LEFT OUTER JOIN dbo.vTranItem AL10 ON (AL1.MMSTranID=AL10.MMSTranID) LEFT OUTER JOIN dbo.vProduct AL11 ON (AL10.ProductID=AL11.ProductID) LEFT OUTER JOIN dbo.vDepartment AL12 ON (AL11.DepartmentID=AL12.DepartmentID) LEFT OUTER JOIN dbo.vReasonCode AL16 ON (AL16.ReasonCodeID=AL1.ReasonCodeID) LEFT OUTER JOIN (select distinct TranItemID, IssuanceAmount from dbo.vTranItemGiftCardIssuance) AL17 ON (AL17.TranItemID=AL10.TranItemID)
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description IN ('Adjustment', '	'))

UNION
---- Returns Refund transactions
SELECT 
AL4.Description, AL2.CloseDateTime, AL7.Description, AL6.ClubName, AL2.DrawerActivityID, AL1.PostDateTime, AL1.MemberID, AL8.FirstName, AL8.LastName, 
AL1.TranVoidedID, AL1.ReceiptNumber, AL1.EmployeeID, AL1.DomainName, AL9.Description, AL14.Description, AL13.PaymentID, AL13.PaymentAmount, 
AL13.PaymentAmount, AL13.PaymentAmount, STR ((7*( AL1.MMSTranID/AL1.MMSTranID)), 1, 0 ), AL14.Description, AL13.ApprovalCode, AL13.PaymentID, AL1.ChangeRendered, AL1.ReceiptComment, AL13.TipAmount, 0.00 as IssuanceAmount, AL18.CardOnFileFlag
FROM 
dbo.vDrawerActivity AL2, dbo.vValDrawerStatus AL4, dbo.vDrawer AL5, dbo.vClub AL6, dbo.vValRegion AL7, dbo.vMMSTran AL1 
LEFT OUTER JOIN dbo.vMember AL8 ON (AL8.MemberID=AL1.MemberID) 
LEFT OUTER JOIN dbo.vValTranType AL9 ON (AL9.ValTranTypeID=AL1.ValTranTypeID) 
LEFT OUTER JOIN dbo.vPayment AL13 ON (AL1.MMSTranID=AL13.MMSTranID) 
LEFT OUTER JOIN dbo.vValPaymentType AL14 ON (AL13.ValPaymentTypeID=AL14.ValPaymentTypeID) 
LEFT OUTER JOIN dbo.vPTCreditCardTransaction AL18 ON (AL18.PaymentID = AL13.PaymentID)
-- limit the result to just Automated Refunds
INNER JOIN dbo.vMMSTranRefund MMSTR ON MMSTR.MMSTranID =  AL1.MMSTranID  
WHERE (AL1.DrawerActivityID=AL2.DrawerActivityID AND AL2.ValDrawerStatusID=AL4.ValDrawerStatusID AND AL2.DrawerID=AL5.DrawerID 
AND AL5.ClubID=AL6.ClubID AND AL6.ValRegionID=AL7.ValRegionID)  AND (AL9.Description='Refund') 
AND AL14.Description IN ('VISA', 'MasterCard', 'American Express', 'Discover')  


