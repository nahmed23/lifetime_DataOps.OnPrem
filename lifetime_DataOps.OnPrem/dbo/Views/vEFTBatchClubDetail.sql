

CREATE VIEW dbo.vEFTBatchClubDetail
AS
SELECT     EFTBatchClubDetailID, EFTBatchID, ClubID, StartTime, LastUpdatedTime, EndTime, TotalCount, ErrorCount, CurrentCount
FROM         MMS.dbo.EFTBatchClubDetail With (NOLOCK)


