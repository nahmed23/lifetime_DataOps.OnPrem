
/*	=============================================
	Object:			mmsPrepareDSSRSummaryData
	Author:			
	Create date: 	
	Description:	THIS PROCEDURE PRE POPULATES DSSR SUMMARY DATA.
	Modified date:	12/09/2009 GRB: added 'Garmin' per QC# 4117;

	Exec mmsPrepareDSSRSummaryData
	=============================================	*/


CREATE      PROCEDURE [dbo].[mmsPrepareDSSRSummaryData]
AS
BEGIN
  SET XACT_ABORT ON
  SET NOCOUNT ON 

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME
  DECLARE @FirstOfNextMonth DATETIME
  DECLARE @LastDayOfPriorMonth DATETIME
  DECLARE @FirstDayOfMonthAfterNext DATETIME

  SET @Yesterday  = DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))
  SET @FirstOfMonth  = CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  = CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)
  SET @FirstOfNextMonth = DATEADD(mm, 1,@FirstOfMonth)
  SET @LastDayOfPriorMonth = DATEADD(dd,-1,@FirstOfMonth)
  SET @FirstDayOfMonthAfterNext = DATEADD(mm, 2,@FirstOfMonth)



  CREATE TABLE #TMPDSSR(MembershipID INT,PostDateTime DATETIME,MemberID INT,TranClubID INT,TranClubName VARCHAR(50),
                      ProductDescription VARCHAR(50),MembershipTypeDescription VARCHAR(50),MembershipSizeDescription VARCHAR(50),
                      PrimaryMemberFirstName VARCHAR(50),MembershipClubID INT,MembershipClubName VARCHAR(50),CreatedDateTime DATETIME,
                      PrimaryMemberLastName VARCHAR(50),AdvisorFirstName VARCHAR(50),AdvisorLastName VARCHAR(50),ItemAmount MONEY,ProductID INT,
                      JoinDate DATETIME,CommissionCount INT,CommEmployeeFirstName VARCHAR(50),TranVoidedID INT,CommEmployeeLastName VARCHAR(50),
                      CompanyID INT,Quantity INT,ExpirationDate DATETIME,MMSTranID INT,TermReasonDescription VARCHAR(50), CommEmployeeID INT,
                      SaleDeptRoleFlag BIT,AdvisorEmployeeID INT,TranTypeDescription VARCHAR(50),TranReasonDescription VARCHAR(50),
                      CorporateAccountRepInitials VARCHAR(5), CorpAccountRepType VARCHAR(50), CorporateCode VARCHAR(50), Post_Today_Flag BIT,
                      Join_Today_Flag BIT, Expire_Today_Flag BIT, Email_OnFile_Flag BIT)

  INSERT INTO #TMPDSSR(MembershipID,PostDateTime,MemberID ,TranClubID ,TranClubName ,ProductDescription ,
                    MembershipTypeDescription ,MembershipSizeDescription ,PrimaryMemberFirstName ,PrimaryMemberLastName,
                    MembershipClubID ,MembershipClubName ,CreatedDateTime  ,AdvisorFirstName ,AdvisorLastName ,
                    ItemAmount ,ProductID ,JoinDate ,CommissionCount ,CommEmployeeFirstName ,TranVoidedID,
                    CommEmployeeLastName ,CompanyID ,Quantity ,ExpirationDate ,MMSTranID ,TermReasonDescription ,CommEmployeeID,
                    AdvisorEmployeeID, TranTypeDescription ,TranReasonDescription ,CorporateAccountRepInitials ,CorpAccountRepType,
                    CorporateCode, Post_Today_Flag, Join_Today_Flag, Expire_Today_Flag, Email_OnFile_Flag)
  SELECT MT.MembershipID, MT.PostDateTime, M.MemberID,C.ClubID,C.ClubName, P.Description ProductDescription,
         P1.Description MembershipTypeDescription,MTFS.Description MembershipSizeDescription,M.FirstName PrimaryMemberFirstName,
         M.LastName PrimaryMemberLastName,C1.ClubID,C1.ClubName,MS.CreatedDateTime,E1.FirstName AdvisorFirstName,
         E1.LastName AdvisorLastName,TI.ItemAmount,P.ProductID, M.JoinDate, 
         CSC.CommissionCount, E.FirstName CommEmployeeFirstName,MT.TranVoidedID,
         E.LastName CommEmployeeLastName,MS.CompanyID,TI.Quantity, MS.ExpirationDate,MT.MMSTranID,VTR.Description TermReasonDescription,
         E.EmployeeID CommEmployeeID, E1.EmployeeID AdvisorEmployeeID, VTT.Description, RC.Description, CO.AccountRepInitials,
         CASE
           WHEN CO.CompanyID = -1 THEN 'Corporate Specialist'
           WHEN VS.Abbreviation IS NOT NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials = 'FC' AND VS.Abbreviation IS NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials = 'BC' AND VS.Abbreviation IS NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials IS NOT NULL AND VS.Abbreviation IS NULL THEN 'Key Account Manager'
           WHEN CO.AccountRepInitials IS NULL AND VS.Abbreviation IS NULL THEN NULL
         ELSE NULL
         END CorpAccountRepType,CO.CorporateCode,
         CASE
           WHEN MT.PostDateTime >= @Yesterday AND MT.PostDateTime < @Today THEN 1
         ELSE 0
         END Post_Today_Flag,
         CASE
           WHEN M.JoinDate >= @Yesterday AND M.JoinDate < @Today THEN 1
         ELSE 0
         END Join_Today_Flag,
         CASE
           WHEN MS.ExpirationDate >= @Yesterday AND MS.ExpirationDate < @Today THEN 1
         ELSE 0
         END Expire_Today_Flag,
         CASE
           WHEN M.EmailAddress IS NULL THEN 0
           WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
         ELSE 1
         END Email_OnFile_Flag
    FROM dbo.vMMSTran MT 
    JOIN dbo.vTranItem TI ON MT.MMSTranID = TI.MMSTranID
    JOIN dbo.vProduct P ON TI.ProductID = P.ProductID
    JOIN dbo.vMembership MS ON MS.MembershipID = MT.MembershipID
    JOIN dbo.vClub C1 ON C1.ClubID = MS.ClubID
    JOIN dbo.vMember M ON MS.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P1 ON MST.ProductID = P1.ProductID
    JOIN dbo.vEmployee E1 ON MS.AdvisorEmployeeID = E1.EmployeeID
    JOIN dbo.vClub C ON C.ClubID = MT.ClubID
    JOIN dbo.vValTranType VTT ON MT.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vReasonCode RC ON MT.ReasonCodeID = RC.ReasonCodeID
    LEFT OUTER JOIN dbo.vValMembershipTypeFamilyStatus MTFS ON MTFS.ValMembershipTypeFamilyStatusID = MST.ValMembershipTypeFamilyStatusID
    LEFT OUTER JOIN dbo.vValTerminationReason VTR ON VTR.ValTerminationReasonID=MS.ValTerminationReasonID
    LEFT OUTER JOIN dbo.vCommissionSplitCalc CSC ON TI.TranItemID = CSC.TranItemID 
    LEFT OUTER JOIN dbo.vSaleCommission SC ON TI.TranItemID = SC.TranItemID
    LEFT OUTER JOIN dbo.vEmployee E ON SC.EmployeeID = E.EmployeeID 
    LEFT OUTER JOIN dbo.vCompany CO ON MS.CompanyID = CO.CompanyID
    LEFT OUTER JOIN dbo.vValState VS ON CO.AccountRepInitials = VS.Abbreviation
   WHERE MT.PostDateTime >= @FirstOfMonth AND   
         MT.PostDateTime < @ToDay AND
         MT.TranVoidedID IS NULL AND
         (P.Productid IN (88,89,156,154,155,174,286,316,317,1416,1417,1484,1485,1865,1866,21,22,23,37,38,39,318,319,321,322,1648,2123,2124,2125,2349,3132) 
          OR P.Description LIKE 'Short Term%'
          OR P.CompletePackageFlag = 1
          OR (P.Description LIKE 'Polar%' AND P.DepartmentID = 7)
          OR (P.Description LIKE 'Garmin%' AND P.DepartmentID = 7)		-- added 12/9/2009 GRB
          OR ( P.DepartmentID IN (9,10,19)AND TI.ItemAmount <> 0 )
         ) AND
         M.ValMemberTypeID = 1

  INSERT INTO #TMPDSSR(MembershipID,PostDateTime,MemberID ,TranClubID ,TranClubName ,ProductDescription ,
                    MembershipTypeDescription ,MembershipSizeDescription ,PrimaryMemberFirstName ,PrimaryMemberLastName,
                    MembershipClubID ,MembershipClubName ,CreatedDateTime  , AdvisorFirstName ,AdvisorLastName ,
                    ItemAmount ,ProductID ,JoinDate ,CommissionCount ,CommEmployeeFirstName ,TranVoidedID,
                    CommEmployeeLastName ,CompanyID ,Quantity ,ExpirationDate,MMSTranID,TermReasonDescription,AdvisorEmployeeID,
                    CorporateAccountRepInitials,CorpAccountRepType,CorporateCode,Join_Today_Flag, Email_OnFile_Flag)
  SELECT MS.MembershipID,NULL,M.MemberID,NULL,NULL,NULL,P.Description MembershipTypeDescription,MTFS.Description MembershipSizeDescription,
         M.FirstName, M.LastName, C.ClubID, C.ClubName,  MS.CreatedDateTime,E.FirstName AdvisorFirstName, E.LastName AdvisorLastName,
         NULL,NULL,M.JoinDate,NULL,NULL,NULL ,NULL,MS.CompanyID,NULL,MS.ExpirationDate,NULL,VTR.Description TermReasonDescription,
         E.EmployeeID AdvisorEmployeeID, CO.AccountRepInitials,
         CASE
           WHEN CO.CompanyID = -1 THEN 'Corporate Specialist'
           WHEN VS.Abbreviation IS NOT NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials = 'FC' AND VS.Abbreviation IS NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials = 'BC' AND VS.Abbreviation IS NULL THEN 'Corporate Specialist'
           WHEN CO.AccountRepInitials IS NOT NULL AND VS.Abbreviation IS NULL THEN 'Key Account Manager'
           WHEN CO.AccountRepInitials IS NULL AND VS.Abbreviation IS NULL THEN NULL
         ELSE NULL
         END CorpAccountRepType,CO.CorporateCode,
         CASE
           WHEN M.JoinDate >= @Yesterday AND M.JoinDate < @Today THEN 1
         ELSE 0
         END Join_Today_Flag,
         CASE
           WHEN M.EmailAddress IS NULL THEN 0
           WHEN LTRIM(RTRIM(M.EmailAddress)) = '' THEN 0
         ELSE 1
         END Email_OnFile_Flag
    FROM dbo.vClub C 
    JOIN dbo.vMembership MS 
         ON C.ClubID = MS.ClubID
    JOIN dbo.vMember M 
         ON MS.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MT 
         ON MS.MembershipTypeID = MT.MembershipTypeID
    JOIN dbo.vProduct P 
         ON MT.ProductID = P.ProductID
    JOIN dbo.vEmployee E 
         ON MS.AdvisorEmployeeID = E.EmployeeID
    JOIN dbo.vValMembershipTypeFamilyStatus MTFS 
         ON MTFS.ValMembershipTypeFamilyStatusID = MT.ValMembershipTypeFamilyStatusID
    LEFT OUTER JOIN dbo.vValTerminationReason VTR ON VTR.ValTerminationReasonID=MS.ValTerminationReasonID
    LEFT OUTER JOIN dbo.vCompany CO ON MS.CompanyID = CO.CompanyID
    LEFT JOIN #TMPDSSR T ON MS.MembershipID = T.MembershipID
    LEFT OUTER JOIN dbo.vValState VS ON CO.AccountRepInitials = VS.Abbreviation
   WHERE M.ValMemberTypeID = 1 AND
         M.JoinDate >=  @FirstOfMonth AND
         M.JoinDate <= @Yesterday AND
         P.Description NOT LIKE '%Employee%' AND 
         P.Description NOT LIKE '%Short%' AND 
         T.MembershipID IS NULL

  INSERT INTO #TMPDSSR(MembershipID,PostDateTime,MemberID ,TranClubID ,TranClubName ,ProductDescription ,
                    MembershipTypeDescription ,MembershipSizeDescription ,PrimaryMemberFirstName ,PrimaryMemberLastName,
                    MembershipClubID ,MembershipClubName ,CreatedDateTime  , AdvisorFirstName ,AdvisorLastName ,
                    ItemAmount ,ProductID ,JoinDate ,CommissionCount ,CommEmployeeFirstName ,TranVoidedID,
                    CommEmployeeLastName ,CompanyID ,Quantity ,ExpirationDate,MMSTranID,TermReasonDescription,AdvisorEmployeeID,
                    Expire_Today_Flag)
  SELECT MS.MembershipID,NULL,M.MemberID,NULL,NULL,NULL,P.Description,MTFS.Description,M.FirstName,
         M.LastName ,C.ClubID,C.ClubName,MS.CreatedDateTime,E.FirstName AdvisorFirstName,E.LastName AdvisorLastName,
         NULL,NULL,M.JoinDate,NULL,NULL,NULL,NULL,MS.CompanyID,NULL,MS.ExpirationDate,NULL,
         VTR.Description TermReasonDescription,E.EmployeeID AdvisorEmployeeID,
         CASE
           WHEN MS.ExpirationDate >= @Yesterday AND MS.ExpirationDate < @Today THEN 1
         ELSE 0
         END Expire_Today_Flag
    FROM dbo.vClub C JOIN dbo.vMembership MS ON C.ClubID=MS.ClubID
    JOIN dbo.vMember M ON M.MembershipID=MS.MembershipID
    JOIN dbo.vValTerminationReason VTR ON VTR.ValTerminationReasonID=MS.ValTerminationReasonID
    JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID 
    JOIN dbo.vMembershipType MT ON MS.MembershipTypeID=MT.MembershipTypeID 
    JOIN dbo.vProduct P ON MT.ProductID=P.ProductID
    LEFT JOIN #TMPDSSR T ON MS.MembershipID = T.MembershipID
    LEFT OUTER JOIN vValMembershipTypeFamilyStatus MTFS ON MT.ValMembershipTypeFamilyStatusID = MTFS.ValMembershipTypeFamilyStatusID
   WHERE M.ValMemberTypeID=1 AND 
         MS.ExpirationDate >= @LastDayOfPriorMonth AND  
         MS.ExpirationDate < @FirstDayOfMonthAfterNext AND
         P.Description NOT LIKE '%Employee%' AND 
         P.Description NOT LIKE '%Short%' AND 
         T.MembershipID IS NULL

  UPDATE #TMPDSSR

     SET SaleDeptRoleFlag = 1
    FROM #TMPDSSR T JOIN vEmployeeRole ER ON T.CommEmployeeID = ER.EmployeeID
                    JOIN vValEmployeeRole VER ON ER.ValEmployeeRoleID = VER.ValEmployeeRoleID
   WHERE VER.DepartmentID = 1

--POPULATE DSSRSummary
  TRUNCATE TABLE DSSRSummary

  INSERT INTO DSSRSummary(MembershipID ,PostDateTime ,MemberID,TranClubID,TranClubName,
                      ProductDescription,MembershipTypeDescription,MembershipSizeDescription,
                      PrimaryMemberFirstName,MembershipClubID,MembershipClubName,CreatedDateTime,
                      PrimaryMemberLastName,AdvisorFirstName,AdvisorLastName,ItemAmount,ProductID,
                      JoinDate,CommissionCount,CommEmployeeFirstName,TranVoidedID,CommEmployeeLastName,
                      CompanyID,Quantity,ExpirationDate,MMSTranID,TermReasonDescription,CommEmployeeID,
                      SaleDeptRoleFlag,AdvisorEmployeeID,TranTypeDescription,TranReasonDescription,
                      CorporateAccountRepInitials,CorpAccountRepType,CorporateCode,Post_Today_Flag,
                      Join_Today_Flag,Expire_Today_Flag,Email_OnFile_Flag)
  SELECT MembershipID ,PostDateTime ,MemberID,TranClubID,TranClubName,
         ProductDescription,MembershipTypeDescription,MembershipSizeDescription,
         PrimaryMemberFirstName,MembershipClubID,MembershipClubName,CreatedDateTime,
         PrimaryMemberLastName,AdvisorFirstName,AdvisorLastName,ItemAmount,ProductID,
         JoinDate,CommissionCount,CommEmployeeFirstName,TranVoidedID,CommEmployeeLastName,
         CompanyID,Quantity,ExpirationDate,MMSTranID,TermReasonDescription,CommEmployeeID,
         SaleDeptRoleFlag,AdvisorEmployeeID,TranTypeDescription,TranReasonDescription,
         CorporateAccountRepInitials,CorpAccountRepType,CorporateCode,Post_Today_Flag,
         Join_Today_Flag,Expire_Today_Flag,Email_OnFile_Flag
    FROM #TMPDSSR

--POPULATE DSSR EMPLOYEE TOTAL MEMBERSHIPS SUMMARY.
  TRUNCATE TABLE DSSRAdvisorMembershipTotalsSummary

  INSERT INTO DSSRAdvisorMembershipTotalsSummary(MembershipCount,AdvisorFirstName,AdvisorLastName,ClubID,ClubName,DomainNamePrefix,ValTerminationReasonID,ExpirationDate,AdvisorEmployeeID)
  SELECT COUNT (DISTINCT (MS.MembershipID)) MembershipCount,
         E.FirstName AdvisorFirstName,
         E.LastName AdvisorLastName, C.ClubID,
         C.ClubName,C.DomainNamePrefix,MS.ValTerminationReasonID,MS.ExpirationDate,MS.AdvisorEmployeeID
    FROM dbo.vValMembershipStatus VMS 
    JOIN dbo.vMembership MS ON VMS.ValMembershipStatusID=MS.ValMembershipStatusID
    JOIN dbo.vMember M ON M.MembershipID = MS.MembershipID AND M.ValMemberTypeID = 1
    JOIN dbo.vClub C ON MS.ClubID = C.ClubID
    JOIN dbo.vMembershipType MT ON MS.MembershipTypeID = MT.MembershipTypeID
    JOIN dbo.vProduct P ON MT.ProductID = P.ProductID
    LEFT OUTER JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID
   WHERE (MS.ExpirationDate IS NULL OR MS.ExpirationDate >@Yesterday) AND
         ISNULL(M.JoinDate,'JAN 01 2000') <= @Yesterday AND
         VMS.ValMembershipStatusID IN (2,4,6) AND ---- Pending Termination, Active and Non-Paid Active status
         C.ValPresaleID = 1 AND ---- For open clubs
         P.Description NOT LIKE '%Employee%' AND 
         P.Description NOT LIKE '%Short%' AND
         P.Description NOT LIKE '%Trade%' AND
         P.Description NOT LIKE '%Investor%' AND
         MS.MembershipTypeID <> 134 AND ---- No house Accounts
         (MS.ActivationDate <= @Yesterday OR MS.ActivationDate IS NULL)
   GROUP BY E.FirstName, E.LastName, C.ClubName,C.ClubID, C.DomainNamePrefix,MS.ValTerminationReasonID,MS.ExpirationDate,AdvisorEmployeeID

  INSERT INTO DSSRAdvisorMembershipTotalsSummary(MembershipCount,AdvisorFirstName,AdvisorLastName,ClubID,ClubName,DomainNamePrefix,ValTerminationReasonID,ExpirationDate,AdvisorEmployeeID)
  SELECT COUNT (DISTINCT (MS.MembershipID)) MembershipCount,
         E.FirstName AdvisorFirstName,
         E.LastName AdvisorLastName, C.ClubID,
         C.ClubName,C.DomainNamePrefix,MS.ValTerminationReasonID,MS.ExpirationDate,MS.AdvisorEmployeeID
    FROM dbo.vValMembershipStatus VMS 
    JOIN dbo.vMembership MS ON VMS.ValMembershipStatusID=MS.ValMembershipStatusID
    JOIN dbo.vMember M ON M.MembershipID = MS.MembershipID AND M.ValMemberTypeID = 1
    JOIN dbo.vClub C ON MS.ClubID = C.ClubID
    JOIN dbo.vMembershipType MT ON MS.MembershipTypeID = MT.MembershipTypeID
    JOIN dbo.vProduct P ON MT.ProductID = P.ProductID
    LEFT OUTER JOIN dbo.vEmployee E ON MS.AdvisorEmployeeID=E.EmployeeID
   WHERE (MS.ExpirationDate IS NULL OR MS.ExpirationDate >@Yesterday) AND
         ISNULL(M.JoinDate,'JAN 01 2000') <= @Yesterday AND
         VMS.ValMembershipStatusID <> 1 AND ---- Any membership not terminated
         C.ValPresaleID <> 1 AND ---- For any club that is still in presale
         P.Description NOT LIKE '%Employee%' AND 
         P.Description NOT LIKE '%Short%' AND
         P.Description NOT LIKE '%Trade%' AND
         P.Description NOT LIKE '%Investor%' AND
         MS.MembershipTypeID <> 134 ---- No house Accounts              
   GROUP BY E.FirstName, E.LastName, C.ClubName,C.ClubID, C.DomainNamePrefix,MS.ValTerminationReasonID,MS.ExpirationDate,AdvisorEmployeeID


--POPULATE DSSR SPORTS NON ACCESS SUMMARY.
   TRUNCATE TABLE DSSRSportsNonAccessSummary
    INSERT INTO DSSRSportsNonAccessSummary(MembershipID,ActivationDate,ExpirationDate,CancellationRequestDate,MemberID,
                                        FirstName,LastName,ClubID,ClubName,Today_Flag,SignOnDate,TerminationDate)
    SELECT MRP.MembershipID,MRP.ActivationDate,M.ExpirationDate,M.CancellationRequestDate,
           MBR.MemberID,MBR.FirstName,MBR.LastName,M.ClubID, C.ClubName,
           CASE
             WHEN DATEDIFF(d, M.ExpirationDate,MRP.ActivationDate) = 1 
                  AND M.CancellationRequestDate >= @Yesterday
                  AND M.CancellationRequestDate < @Today THEN 1
             WHEN DATEDIFF(d, M.ExpirationDate,MRP.ActivationDate) <> 1
                  AND MRP.ActivationDate >= @Yesterday
                  AND MRP.ActivationDate < @Today THEN 1
           ELSE 0
           END Today_Flag,
           CASE 
              WHEN DATEDIFF(d,M.ExpirationDate, MRP.ActivationDate)= 1
              THEN M.CancellationRequestDate
           ELSE MRP.ActivationDate
           END SignOnDate,MRP.TerminationDate
    FROM vMembershipRecurrentProduct MRP JOIN vMembership M ON MRP.MembershipID = M.MembershipID
                                         JOIN vProduct P ON MRP.ProductID = P.ProductID
                                         JOIN vMember MBR ON M.MembershipID = MBR.MembershipID
                                         JOIN dbo.vClub C ON C.ClubID = M.ClubID
    WHERE (MRP.TerminationDate >= @FirstOfMonth OR MRP.TerminationDate IS NULL)
        AND P. ValRecurrentProductTypeID = 1
        AND MBR.ValMemberTypeID = 1


  DROP TABLE #TMPDSSR


END
