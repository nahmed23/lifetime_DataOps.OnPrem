CREATE VIEW dbo.vValRefundApprovalReason AS 
SELECT ValRefundApprovalReasonID,Description,SortOrder
FROM MMS.dbo.ValRefundApprovalReason WITH(NOLOCK)
