
CREATE PROC [dbo].[mmsTargetMailingProgram_MemberInterestProfile] (
    @InterestList VARCHAR(1000),
    @MMSClubIDList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT item Interest
  INTO #InterestList
  FROM fnParsePipeList(@InterestList)

SELECT item ClubID
  INTO #MMSClubIDList
  FROM fnParsePipeList(@MMSClubIDList)

SELECT M.MemberID,
       M.FirstName,
       M.LastName,
       M.MembershipID,
       CID.Item,
       MAX(MCI.InsertedDateTime) InterestInsertedDateTime,
       MT.Description MemberType,
       CID.MIPCategoryItemID,
       CID.ValMIPItemID,
       CID.ActiveFlag
  FROM vMIPCategoryItemDescription CID
  JOIN #InterestList
    ON CID.Item = #InterestList.Interest
  JOIN vMIPMemberCategoryItem MCI
    ON CID.MIPCategoryItemID = MCI.MIPCategoryItemID
  JOIN vMember M
    ON M.MemberID = MCI.MemberID
  JOIN vValMemberType MT
    ON MT.ValMemberTypeID = M.ValMemberTypeID
  JOIN vMembership MS
    ON M.MembershipID = MS.MembershipID
  JOIN #MMSClubIDList
    ON MS.ClubID = #MMSClubIDList.ClubID
  JOIN vValMembershipStatus VMS
    ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN vClub C
    ON C.ClubID = MS.ClubID
 WHERE M.ActiveFlag = 1
   AND VMS.Description <> 'Terminated'
 GROUP BY M.MemberID,
          M.FirstName,
          M.LastName,
          M.MembershipID,
          CID.Item,
          MT.Description,
          CID.MIPCategoryItemID,
          CID.ValMIPItemID,
          CID.ActiveFlag
 ORDER BY M.MembershipID, M.MemberID


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
