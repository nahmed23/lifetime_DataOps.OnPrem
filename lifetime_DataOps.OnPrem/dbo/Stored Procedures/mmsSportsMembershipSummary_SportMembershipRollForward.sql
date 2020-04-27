









--
-- returns Member status info for the SportsMemberstatussummary Brio bqy
--

CREATE       PROC dbo.mmsSportsMembershipSummary_SportMembershipRollForward
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @EndOfLastMonth SMALLDATETIME
DECLARE @EndOfThisMonth SMALLDATETIME
DECLARE @FirstOfThisMonth SMALLDATETIME
DECLARE @FirstOfLastMonth SMALLDATETIME
DECLARE @FirstOfNextMonth SMALLDATETIME

SET @FirstOfThisMonth = CAST(CAST(MONTH(GETDATE()) AS VARCHAR(5)) + '/1/' + CAST(YEAR(GETDATE()) AS VARCHAR(5)) AS DATETIME)
SET @EndOfLastMonth = DATEADD(day, -1, @FirstOfThisMonth)
SET @EndOfThisMonth = DATEADD(day, -1, DATEADD(month, 1, @FirstOfThisMonth))
SET @FirstOfLastMonth = DATEADD(month, -1, @FirstOfThisMonth)
SET @FirstOfNextMonth = DATEADD(month, 1, @FirstOfThisMonth)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT VR.Description RegionDescription, C.ClubName, C.DomainNamePrefix,
       MS.MembershipID, VMS.Description MembershipStatusDescr, GETDATE() Today,
       MS.CreatedDateTime, M.JoinDate, MS.ExpirationDate,
       ISNULL(T1.PostDateTime,'Jan 1,1900')AS PostDateTime, T2.Membership_Count, T3.New_Membership_Count,
       P.Description MembershipTypeDescription,
       @EndOfLastMonth EndOfLastMonth, @EndOfThisMonth EndOfThisMonth,
       @FirstOfLastMonth FirstOfLastMonth, @FirstOfThisMonth FirstOfThisMonth,
       @FirstOfNextMonth FirstOfNextMonth,
       CASE WHEN VMS.ValMembershipStatusID != 1 THEN 0
            WHEN MS.ExpirationDate > @EndOfLastMonth AND
                 MS.ExpirationDate <= @EndOfThisMonth OR
                 MS.ExpirationDate IS NULL THEN 1
            ELSE 0
       END TermedThisMonth,
       CASE WHEN VMS.ValMembershipStatusID != 2 THEN 0
            WHEN MS.ExpirationDate > @EndOfLastMonth AND
                 MS.ExpirationDate <= @EndOfThisMonth OR
                 MS.ExpirationDate IS NULL THEN 1
            ELSE 0
       END YetToTermThisMo
  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID=MS.MembershipID
  JOIN dbo.vValMemberType VMT
       ON M.ValMemberTypeID=VMT.ValMemberTypeID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID=MS.ValMembershipStatusID
  JOIN dbo.vClub C
       ON MS.ClubID=C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID=VR.ValRegionID
  JOIN dbo.vClubProduct CP
       ON C.ClubID=CP.ClubID
  JOIN dbo.vMembershipType MST
       ON MST.MembershipTypeID=MS.MembershipTypeID
  JOIN dbo.vProduct P 
       ON P.ProductID=CP.ProductID AND
       MST.ProductID=P.ProductID
  LEFT JOIN (
    SELECT MS.MembershipID, MAX(MMST.PostDateTime) PostDateTime
      FROM dbo.vMMSTran MMST
      JOIN dbo.vTranItem TI
           ON MMST.MMSTranID = TI.MMSTranID
      JOIN dbo.vProduct P
           ON TI.ProductID = P.ProductID
      JOIN dbo.vMember M
           ON M.MemberID = MMST.MemberID
      JOIN dbo.vMembership MS
           ON MS.MembershipID = M.MembershipID
      JOIN dbo.vValMembershipStatus VMSS
           ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
      JOIN dbo.vMembershipType MST
           ON MS.MembershipTypeID = MST.MembershipTypeID
     WHERE P.Description = 'LTF Sport Upgrade' AND
           VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
           MMST.TranVoidedID IS NULL
     GROUP BY MS.MembershipID
     HAVING SUM(TI.ItemAmount) > 0
       ) T1
       ON T1.MembershipID = MS.MembershipID
  LEFT JOIN (
    SELECT MS.ClubID, COUNT (DISTINCT (MS.MembershipID)) AS Membership_Count
      FROM dbo.vMembership MS
      JOIN dbo.vClub C
           ON MS.ClubID = C.ClubID
      JOIN dbo.vValMembershipStatus VMSS 
           ON MS.ValMembershipStatusID = VMSS.ValMembershipStatusID
     WHERE VMSS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
           (MS.ExpirationDate is null) OR 
           (MS.ExpirationDate  > GETDATE() ) 
     GROUP BY MS.ClubID
       ) T2
       ON T2.ClubID = C.ClubID
  LEFT JOIN (
    SELECT MS.ClubID, COUNT (DISTINCT (MS.MembershipID)) AS New_Membership_Count
      FROM dbo.vMembership MS 
      JOIN dbo.vClub C
           ON MS.ClubID = C.ClubID
      JOIN dbo.vMember M
           ON M.MembershipID = MS.MembershipID
      JOIN dbo.vMembershipType MST
           ON MS.MembershipTypeID = MST.MembershipTypeID
      JOIN dbo.vProduct P 
           ON MST.ProductID = P.ProductID
     WHERE M.ValMemberTypeID = 1 AND
           M.JoinDate >=  cast(DATEPART(month,GETDATE()) as varchar(2))+'/01/'+ cast(DATEPART(year,GETDATE()) as varchar(4)) AND
           (NOT (P.Description LIKE '%Employee%' OR 
           P.Description LIKE '%Old Fitness%' OR 
           P.Description LIKE '%Short%' OR 
           P.Description LIKE '%Trade%')) 
     GROUP BY MS.ClubID
       ) T3
       ON T3.ClubID = C.ClubID
 WHERE VMT.Description='Primary' AND
       C.DisplayUIFlag=1 AND
       (MS.ExpirationDate IS NULL OR 
       MS.ExpirationDate>=DATEADD ( day, -33, Getdate() )) AND
       (P.Description LIKE '%Junior%' OR 
       P.Description LIKE '%Sport%'OR P.Description LIKE '%Elite%') AND
       (NOT (P.Description LIKE '%Employee%' OR 
       P.Description LIKE '%Old Fitness%' OR 
       P.Description LIKE '%Short%' OR 
       P.Description LIKE '%Trade%'))
 ORDER BY T1.PostDateTime DESC


-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END






