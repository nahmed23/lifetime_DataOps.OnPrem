﻿CREATE VIEW dbo.vRefundMembershipPayment AS 
SELECT RefundMembershipPaymentID,MMSTranRefundID,OriginalPaymentID,Description,PaymentAmount
FROM MMS_Archive.dbo.RefundMembershipPayment WITH(NOLOCK)
