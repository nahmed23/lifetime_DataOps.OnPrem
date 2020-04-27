

-- Procedure to get membership details for Non terminated memberships per club
--
-- Parameters:  List of regions separated by |

CREATE       PROC dbo.mmsMemDetail_Scheduled(
                 @RegionList VARCHAR(1000))
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Regions (RegionName VARCHAR(50))

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

--INSERT INTO #Clubs EXEC procParseStringList @ClubList
EXEC procParseStringList @RegionList
INSERT INTO #Regions (RegionName) SELECT StringField FROM #tmpList

SELECT C.ClubName, M.MemberID, M.FirstName,
       M.LastName, M.JoinDate, MSP.ValPhoneTypeID,
       MSP.AreaCode, MSP.Number, MS.MembershipID,
       MSB.CurrentBalance, VR.Description AS RegionDescription, 
       VMSS.Description AS MembershipStatusDescription,
       MS.ActivationDate, MS.CancellationRequestDate, P.Description AS MembershipTypeDescription,
       GETDATE() AS ReportDate
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus VMSS
       ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID = VMT.ValMemberTypeID
  LEFT JOIN dbo.vPrimaryPhone PP
       ON (MS.MembershipID = PP.MembershipID)
  LEFT JOIN dbo.vMembershipPhone MSP
       ON (PP.MembershipID = MSP.MembershipID AND PP.ValPhoneTypeID = MSP.ValPhoneTypeID)
  LEFT JOIN dbo.vMembershipBalance MSB
       ON (MSB.MembershipID = MS.MembershipID)
  JOIN #Regions R
       ON R.RegionName = VR.Description 
 WHERE 
       VMSS.ValMembershipStatusID <> 1 AND
       VMT.ValMemberTypeID = 1 AND
       P.DepartmentID = 1 AND
       P.ProductID NOT  IN (88, 89, 90, 153) AND
       C.DisplayUIFlag = 1

DROP TABLE #Regions
DROP TABLE #tmpList


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

