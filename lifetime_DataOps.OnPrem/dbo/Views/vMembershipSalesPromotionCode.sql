﻿CREATE VIEW dbo.vMembershipSalesPromotionCode AS 
SELECT MembershipSalesPromotionCodeID,MembershipID,MemberID,SalesPromotionCodeID,SalesAdvisorEmployeeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MembershipSalesPromotionCode WITH(NOLOCK)
