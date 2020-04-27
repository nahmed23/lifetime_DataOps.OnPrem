




----------------------------------------------------- dbo.mmsTranBalanceInsert
CREATE PROCEDURE
       [dbo].[mmsTranBalanceInsert] ( @TranItemCount INT = 0 )
AS

  SET XACT_ABORT ON
  SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY


  IF ( @TranItemCount IS NULL
       OR
       @TranItemCount  < 0 )
     SET @TranItemCount = 0

  DECLARE @Today                                       DATETIME
  DECLARE @MembershipID                                INT
  DECLARE @MembershipID2                               INT
  DECLARE @CommittedBalance                            MONEY
  DECLARE @CommittedBalance2                           MONEY
  DECLARE @CommittedBalanceProducts                    MONEY       --EFT Draft Separation Project
  DECLARE @AssessAsDuesFlag                            INT         --EFT Draft Separation Project
  DECLARE @TranItemID                                  INT
  DECLARE @TranItemID2                                 INT
  DECLARE @ItemTotal                                   MONEY
  DECLARE @ItemTotal2                                  MONEY
  DECLARE @CurrentMembershipID                         INT
  DECLARE @CommittedBalanceAmountRemaining             MONEY       --EFT Draft Separation Project
  DECLARE @CommittedBalanceProductsAmountRemaining     MONEY       --EFT Draft Separation Project
  DECLARE @TranBalanceID                               INT
  DECLARE @ReasonCodeID								   INT		   --EFT Draft Separation Project

  SET @Today = CAST( CONVERT( VARCHAR, GETDATE(), 101 ) AS DATETIME ) 

  WHILE @TranItemCount > ( SELECT COUNT(*)
                           FROM   vTranItem
                           WHERE  InsertedDateTime > @Today )
  BEGIN
    WAITFOR DELAY '00:05:00'
  END


  SELECT MT.MembershipID,
         TI.TranItemID,
         MT.PostDateTime,
		 ISNULL(Convert(INT,P.AssessAsDuesFlag),2) AssessAsDuesFlag,  --EFT Draft Separation Project
         TI.ItemAmount + TI.ItemSalesTax ItemTotal,
		 MT.ReasonCodeID
    INTO #CommittedTrans
    FROM vMMSTran MT 
         JOIN vTranItem TI
           ON MT.MMSTranID = TI.MMSTranID
          AND DATEDIFF(DAY, MT.PostDateTime, GETDATE()) <= 120 -- Only go back four months
          AND MT.TranVoidedID IS NULL -- Don't include voided trans
          AND MT.TranAmount > 0       -- Don't include POS or payments/adjustments
          AND MT.MembershipID <> -1   -- Don't included the Legacy House Account
          AND MT.DrawerActivityID IN
              (SELECT DrawerActivityID
                 FROM vDrawerActivity
                WHERE ValDrawerStatusID = 3) -- Only include items from closed drawers
		 JOIN vProduct P --EFT Draft Separation Project
           ON P.ProductID = TI.ProductID

  DECLARE TranBalanceCur CURSOR LOCAL FOR
    SELECT MB.MembershipID,
           MB.CommittedBalance,
		   ISNULL(MB.CommittedBalanceProducts,0),  --EFT Draft Separation Project
           X.TranItemID,
           X.ItemTotal,
		   X.AssessAsDuesFlag,  --EFT Draft Separation Project
		   X.ReasonCodeID
      FROM vMembershipBalance MB
       Join vMembership MS
         On MB.MembershipID = MS.MembershipID
       LEFT JOIN #CommittedTrans X
             ON MB.MembershipID = X.MembershipID
     WHERE MB.MembershipID <> -1
      AND((MS.ValMembershipStatusID = 1 and MB.CommittedBalance <> 0 ) OR MS.ValMembershipStatusID > 1)
        ----AND MS.MembershipID in(742,1142234,1142240,1142244,3359474,3364992,3376803)   --- for testing purposes only
     ORDER BY MB.MembershipID ASC, X.PostDateTime DESC

BEGIN
--Modified This to solve the duplicate key problem in Replication.
  SELECT @TranBalanceID = ISNULL(MAX(TranBalanceID),0)
  FROM vTranBalance

--  TRUNCATE TABLE TranBalance -- Temporarily turned off until we find a way for CommonDev to do this
  ----DELETE MMS_DB04.dbo.TranBalance   ---- for DEV/QA testing only
  ----DELETE MMS_SystemTest_Replicated.dbo.TranBalance   ---- for DEV/QA testing only
     DELETE MMS.dbo.TranBalance
  OPEN TranBalanceCur
  FETCH NEXT FROM TranBalanceCur
    INTO @MembershipID, @CommittedBalance, @CommittedBalanceProducts, @TranItemID, @ItemTotal, @AssessAsDuesFlag,@ReasonCodeID

  SET @CurrentMembershipID = -999
  SET @CommittedBalanceAmountRemaining = 0
  SET @CommittedBalanceProductsAmountRemaining = 0

  WHILE @@FETCH_STATUS = 0
  BEGIN
    ------ Next record is a new membership but there is a remaining dues balance for the existing membership 
    IF (@CurrentMembershipID <> @MembershipID) AND (@CommittedBalanceAmountRemaining > 0.00)  
      BEGIN
        SET @TranBalanceID = @TranBalanceID + 1
        INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory )
        ----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)   ---- for DEV/QA testing only
		----INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)   ---- for DEV/QA testing only
          VALUES (@TranBalanceID, NULL, @CurrentMembershipID, @CommittedBalanceAmountRemaining, 'Dues')

        SET @CommittedBalanceAmountRemaining = 0.00
      END
  
    ------ There is a dues credit balance for the current membership and the next record is a new membership 
    IF @CommittedBalance < 0.00 
    BEGIN
      IF @CurrentMembershipID <> @MembershipID
      BEGIN
        -- This Membership does not have a positive balance so only one TranBalance record needs to
        -- be created containing the negative committed balance
        SET @TranBalanceID = @TranBalanceID + 1
        INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount, TranProductCategory)
        ----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
		----INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
          VALUES (@TranBalanceID, Null, @MembershipID, @CommittedBalance,'Dues')
      END
    END
	--EFT Draft Separation Project Begin
	------ Next record is a new membership but there is a remaining products balance for the existing membership 
	IF (@CurrentMembershipID <> @MembershipID) AND (@CommittedBalanceProductsAmountRemaining > 0.00) 
        
      BEGIN
        SET @TranBalanceID = @TranBalanceID + 1
        INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)
        ------INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)   ---- for DEV/QA testing only
        ------INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)   
		  VALUES (@TranBalanceID, NULL, @CurrentMembershipID, @CommittedBalanceProductsAmountRemaining, 'Products')

        SET @CommittedBalanceProductsAmountRemaining = 0.00
      END
  
    ------ There is a products credit balance for the current membership and the next record is a new membership
    IF @CommittedBalanceProducts < 0.00 
    BEGIN
      IF @CurrentMembershipID <> @MembershipID
      BEGIN
        -- This Membership does not have a positive balance so only one TranBalance record needs to
        -- be created containing the negative products committed balance 
        SET @TranBalanceID = @TranBalanceID + 1
        INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount, TranProductCategory)
        ----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
        ----INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only  
		  VALUES (@TranBalanceID, Null, @MembershipID, @CommittedBalanceProducts,'Products')
      END
    END
	--EFT Draft Separation Project End

    IF @CurrentMembershipID <> @MembershipID
    BEGIN
      SET @CurrentMembershipID = @MembershipID
      SET @CommittedBalanceAmountRemaining = @CommittedBalance
	  SET @CommittedBalanceProductsAmountRemaining = @CommittedBalanceProducts --EFT Draft Separation Project 
    END

    IF @CommittedBalance > 0.00 AND (@AssessAsDuesFlag = 1 OR @ReasonCodeID <> 114 ) 
    BEGIN
      IF @CommittedBalanceAmountRemaining > 0.00
      BEGIN
        IF @CommittedBalanceAmountRemaining > @ItemTotal
        BEGIN
          SET @TranBalanceID = @TranBalanceID + 1
          INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory )
          ----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
          ----INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
		    VALUES (@TranBalanceID, @TranItemID, @MembershipID, @ItemTotal, 'Dues')
          SET @CommittedBalanceAmountRemaining = @CommittedBalanceAmountRemaining - @ItemTotal
        END
        ELSE
        BEGIN
          -- If we are here with a NULL TranItemID then this means the Membership doesn't have any
          -- transacations that are less than four months old so we need to check the older
          -- transactions to create the TranBalance records
          IF @TranItemID IS NOT NULL AND (@AssessAsDuesFlag = 1 OR @ReasonCodeID <> 114 )
          BEGIN
            SET @TranBalanceID = @TranBalanceID + 1
            INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)
            ---INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
            ---INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
			  VALUES (@TranBalanceID, @TranItemID, @MembershipID, @CommittedBalanceAmountRemaining, 'Dues')
            SET @CommittedBalanceAmountRemaining = 0
          END
        END
      END
    END

	--EFT Draft Separation Project Begin
	IF @CommittedBalanceProducts > 0.00 AND @AssessAsDuesFlag <> 1  AND @ReasonCodeID = 114
    BEGIN
      IF @CommittedBalanceProductsAmountRemaining > 0.00
      BEGIN
        IF @CommittedBalanceProductsAmountRemaining > @ItemTotal
        BEGIN
          SET @TranBalanceID = @TranBalanceID + 1
          INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)
          ---INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
          ---INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only  
			VALUES (@TranBalanceID, @TranItemID, @MembershipID, @ItemTotal, 'Products')
          SET @CommittedBalanceProductsAmountRemaining = @CommittedBalanceProductsAmountRemaining - @ItemTotal
        END
        ELSE
        BEGIN
          -- If we are here with a NULL TranItemID then this means the Membership doesn't have any
          -- transacations that are less than four months old so we need to check the older
          -- transactions to create the TranBalance records
          IF @TranItemID IS NOT NULL AND @AssessAsDuesFlag <> 1  AND @ReasonCodeID = 114
          BEGIN
            SET @TranBalanceID = @TranBalanceID + 1
            INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)
            ---INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
            ---INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only  
			  VALUES (@TranBalanceID, @TranItemID, @MembershipID, @CommittedBalanceProductsAmountRemaining, 'Products')
            SET @CommittedBalanceProductsAmountRemaining = 0
          END
        END
      END
    END
	       ELSE 
      BEGIN
	     ----- this script catches memberships where there is a credit dues balance but no transactions from #CommittedTrans
         IF @CommittedBalance > 0.00 AND @AssessAsDuesFlag IS NULL AND @ReasonCodeID IS NULL AND @TranItemID IS NULL
            BEGIN
            SET @TranBalanceID = @TranBalanceID + 1
            -----INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
			-----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
			INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  
                       VALUES (@TranBalanceID, @TranItemID, @MembershipID, @CommittedBalance, 'Dues')
            SET @CommittedBalanceAmountRemaining = 0
            END
			Else
			  Begin
			   ----- this script catches memberships where there is a credit products balance but no transactions from #CommittedTrans
		       IF @CommittedBalanceProducts > 0.00 AND @AssessAsDuesFlag IS NULL AND @ReasonCodeID IS NULL AND @TranItemID IS NULL
               BEGIN
                 SET @TranBalanceID = @TranBalanceID + 1
                  ---INSERT INTO MMS_SystemTest_Replicated.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
			    -----INSERT INTO MMS_DB04.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  ---- for DEV/QA testing only
			    INSERT INTO MMS.dbo.TranBalance (TranBalanceID, TranItemID, MembershipID, TranBalanceAmount,TranProductCategory)  
                       VALUES (@TranBalanceID, @TranItemID, @MembershipID, @CommittedBalance, 'Products')
                  SET @CommittedBalanceAmountRemaining = 0
               END
             End
       END



	--EFT Draft Separation Project End

    FETCH NEXT FROM TranBalanceCur
      INTO @MembershipID, @CommittedBalance,@CommittedBalanceProducts, @TranItemID, @ItemTotal,@AssessAsDuesFlag,@ReasonCodeID

  END

  CLOSE TranBalanceCur
  DEALLOCATE TranBalanceCur

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




