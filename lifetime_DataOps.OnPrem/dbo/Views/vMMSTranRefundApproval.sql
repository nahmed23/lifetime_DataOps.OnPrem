﻿CREATE VIEW dbo.vMMSTranRefundApproval AS 
SELECT MMSTranRefundApprovalID,ApprovingEmployeeID,ValRefundApprovalReasonID,MMSTranRefundID
FROM MMS_Archive.dbo.MMSTranRefundApproval WITH(NOLOCK)
