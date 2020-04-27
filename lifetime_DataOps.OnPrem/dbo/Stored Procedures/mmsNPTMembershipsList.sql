
CREATE     PROC [dbo].[mmsNPTMembershipsList] 
								@RowsProcessed int output, 
								@Description  varchar(80) output
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON     
     
     DECLARE @LastPostDate AS DATETIME
     DECLARE @ExpirationDate AS DATETIME
     DECLARE @CdtTime AS DATETIME
     DECLARE @CstTime AS DATETIME
     DECLARE @CancellationRequestDate AS DATETIME
     DECLARE @OpenDateTimeZone AS VARCHAR(4)
     DECLARE @UTCOpenDateTime AS DATETIME
     DECLARE @MemMessagCount AS INT
     DECLARE @SequenceValue AS INT
     --FIND OUT THE MOST RECENT POSTDATETIME FROM LAST MONTH AND ExpirationDate WHICH IS THE LAST DAY OF current MONTH
     --SET @LastPostDate = DATEADD(MM,-1,CONVERT(VARCHAR,MONTH(getdate())) + '/01/' + CONVERT(VARCHAR,YEAR(DATEADD(MM,-1,getdate()))))
     SET @LastPostDate = CONVERT(VARCHAR,MONTH(getdate())) + '/01/' + CONVERT(VARCHAR,YEAR(getdate()))
     SET @ExpirationDate = DATEADD(D,-1,DATEADD(M,2,@LastPostDate))
     SET @CancellationRequestDate = DATEADD(M,1,@LastPostDate)
     --SET @ExpirationDate = DATEADD(D,-1,@ExpirationDate)
     --SET @CancellationRequestDate = DATEADD(M,-1,@ExpirationDate) --CONVERT(VARCHAR,MONTH(GETDATE())) + '/25/' + CONVERT(VARCHAR,YEAR(GETDATE()))
     --SELECT ALL MEMBERSHIPS THAT HAVE COMPLETE PENDING BALANCE FOR 2 MONTHS OR MORE,
     --ARE ACTIVE, ARE NOT EMPLOYEES AND DO NOT BELONG TO A CHARGE TO ACCOUNT CLUB.
     
     --SELECT ALL NON EMPLOYEE MEMBERSHIPS' TRANSACTIONS THAT HAVE PENDING DUES BALANCE 
     SELECT MB.MembershipID,MB.CurrentBalance
     INTO #TermMemberships
     FROM vMembershipBalance MB JOIN vMembership MS on MS.MembershipID = MB.MembershipID
                               JOIN vMembershipType MST ON MST.ProductID = MS.MembershipTypeID
                               JOIN vPRODUCT P ON P.ProductID = MST.ProductID 
                               JOIN vClub C ON C.CLUBID = MS.CLUBID
     WHERE MB.CurrentBalance > 0 AND P.Description NOT LIKE '%Employee%'
     AND C.ChargeToAccountFlag = 0 AND MS.ValMembershipStatusID = 4
     AND (MS.ActivationDate < DATEADD(D,1,DATEADD(M,-1,@LastPostDate))
          OR MS.ActivationDate IS NULL)
   

     -- this is to make sure that the NPT process works correctly even if ran after EFTs.
     SELECT TM.MembershipID,TM.CurrentBalance,SUM(TranAmount) TranAmount
     INTO #CurrentMonthBalance
     FROM vMMSTran MT JOIN #TermMemberships TM ON MT.MembershipID = TM.MembershipID
                     LEFT JOIN(SELECT MembershipID FROM vMMSTran WHERE PostDateTime > DATEADD(MM,1,@LastPostDate)  AND ValTranTypeID = 2) X
                      ON MT.MembershipID = X.MembershipID
     WHERE MT.PostDateTime > DATEADD(MM,1,@LastPostDate)
       AND MT.ValTranTypeID = 1
       AND X.MembershipID IS NULL
     GROUP BY TM.MembershipID,TM.CurrentBalance

     UPDATE #TermMemberships
     SET CurrentBalance = TM.CurrentBalance - ISNULL(TranAmount,0)
     FROM #TermMemberships TM JOIN #CurrentMonthBalance CB ON TM.MembershipID = CB.MembershipID
     

     --SELECT MEMBERSHIPS FROM THE LIST SELECTED ABOVE(#TermMemberships) 
     --AND THEIR TOTAL MONTHLY DUES FOR THE LAST TWO MONTHS
     SELECT MT.MembershipID,SUM(MT.TranAmount)-5 ItemTotal,COUNT(MT.MMSTranID) MMSTranCount
     INTO #Membership2MonthBalance
     FROM vMMSTran MT 
         JOIN vTranItem TI
           ON MT.MMSTranID = TI.MMSTranID
         JOIN #TermMemberships TML ON MT.MEMBERSHIPID = TML.MEMBERSHIPID
         JOIN vMembershipType MST ON MST.ProductID = TI.ProductID
          AND MT.PostDateTime >= DATEADD(M,-1,@LastPostDate) 
          AND MT.PostDateTime < DATEADD(M,1,@LastPostDate)
          AND MT.TranVoidedID IS NULL 
          AND MT.TranAmount > 0       
          AND MT.MembershipID <> -1   
          AND MT.DrawerActivityID IN
              (SELECT DrawerActivityID
                 FROM vDrawerActivity
                WHERE ValDrawerStatusID = 3) 
     GROUP BY MT.MEMBERSHIPID

     --SELECT ALL MEMBERSHIPS THAT HAVE AT LEAST A PARTIAL PAYMENT FOR THE PAST TWO MONTHS DUES
     --(IF SUM OF TRANBALANCE IS LESS THAN SUM OF TRANAMOUNT)
     SELECT DISTINCT A.MembershipID
     INTO #PartPaidMemberships
     FROM #TermMemberships A 
                 JOIN #Membership2MonthBalance B 
                   ON A.MembershipID = B.MembershipID 
                  AND A.CurrentBalance < B.ItemTotal

     --DELETE MEMBERSHIPS THAT HAVE AT LEAST A PARTIAL PAYMENT FOR THE PAST TWO MONTHS DUES FROM #TermMemberships LIST
     DELETE #TermMemberships
     FROM #TermMemberships A JOIN #PartPaidMemberships B 
                               ON A.MembershipID = B.MembershipID

     --DELETE #TermMemberships
     --FROM #TermMemberships A JOIN MMSTran B 
                              -- ON A.MembershipID = B.MembershipID
    -- WHERE B.ValTranTypeID = 2
       --   AND B.PostDateTime >= DATEADD(M,-1,@LastPostDate) 
      --    AND B.PostDateTime < DATEADD(M,1,@LastPostDate)

    --DELETE MEMBERSHIPS THAT DON'T HAVE ATLEAST 2 ASSESSMENTS IN THE LAST 2 MONTHS
     DELETE #TermMemberships
     FROM #TermMemberships A LEFT JOIN #Membership2MonthBalance B 
                                ON A.MembershipID = B.MembershipID AND B.MMSTranCount >= 2
     WHERE B.MembershipID IS NULL

     SELECT MA.RowID AS MembershipID
     INTO #UpdatedMemberships  
     FROM  vMembershipAudit MA JOIN vProduct OP on MA.OldValue = OP.ProductID AND (OP.Description LIKE '%Flex%' OR OP.Description LIKE '%Life Time Health%')
                              JOIN vProduct NP on MA.NewValue = NP.ProductID AND NP.Description NOT LIKE '%Flex%' AND NP.Description NOT LIKE '%Life Time Health%'
     WHERE ColumnName = 'MembershipTypeID'
      and ModifiedDateTime > @LastPostDate

     DELETE FROM tmpNPTMembershipsList

     INSERT INTO tmpNPTMembershipsList(MemberID ,FirstName ,LastName ,ClubName ,MembershipType ,EmailAddress ,Phone ,AddressLine1 ,AddressLine2 ,City ,State ,
	             ZIP ,JoinDate ,MembershipSource )
     SELECT M.MEMBERID,M.FIRSTNAME,M.LASTNAME,C.CLUBNAME,P.Description MembershipType,ISNULL(M.EMAILADDRESS,'') EMAILADDRESS,
            ISNUll(MP.AREACODE,'') + ISNULL(NUMBER,'') PHONE,MA.ADDRESSLINE1,isnull(MA.ADDRESSLINE2,'') ADDRESSLINE2,MA.CITY,
            VS.ABBREVIATION,MA.ZIP,M.JoinDate,vms.description MembershipSource
      FROM #TermMemberships TMS JOIN vMEMBERSHIP MS ON TMS.MEMBERSHIPID = MS.MEMBERSHIPID
       JOIN vMEMBER M ON MS.MEMBERSHIPID = M.MEMBERSHIPID AND M.VALMEMBERTYPEID = 1
       JOIN vCLUB C ON MS.CLUBID = C.CLUBID
       JOIN vMEMBERSHIPPHONE MP ON MS.MEMBERSHIPID = MP.MEMBERSHIPID AND MP.VALPHONETYPEID = 1
       JOIN vMEMBERSHIPADDRESS MA ON MS.MEMBERSHIPID = MA.MEMBERSHIPID
       JOIN vVALSTATE VS ON MA.VALSTATEID = VS.VALSTATEID
       JOIN vproduct p on ms.membershiptypeid = p.productid
       JOIN vvalmembershipsource vms on ms.valmembershipsourceid = vms.valmembershipsourceid
       LEFT JOIN #UpdatedMemberships UM ON MS.MembershipID = UM.MembershipID
       WHERE UM.MembershipID IS NULL 
       ORDER BY 3,1

       SELECT @RowsProcessed = COUNT(*) FROM tmpNPTMembershipsList
       SELECT @Description = 'Number of Members in NPT List'

END

