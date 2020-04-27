CREATE TABLE [dbo].[ReportDimDate] (
    [DimDateKey]                            INT          NOT NULL,
    [CalendarDate]                          DATETIME     NOT NULL,
    [FullDateDescription]                   VARCHAR (18) NOT NULL,
    [DayOfWeekName]                         VARCHAR (9)  NOT NULL,
    [DayOfWeekAbbreviation]                 VARCHAR (3)  NOT NULL,
    [DayNumberInCalendarWeek]               NUMERIC (1)  NOT NULL,
    [DayNumberInCalendarMonth]              NUMERIC (2)  NOT NULL,
    [DayNumberInCalendarQuarter]            NUMERIC (3)  NOT NULL,
    [DayNumberInCalendarYear]               NUMERIC (3)  NOT NULL,
    [NumberOfDaysInMonth]                   NUMERIC (2)  NOT NULL,
    [WeekdayIndicator]                      CHAR (1)     NOT NULL,
    [LastDayInWeekIndicator]                CHAR (1)     NOT NULL,
    [LastDayInMonthIndicator]               CHAR (1)     NOT NULL,
    [CalendarWeekEndingDate]                DATETIME     NOT NULL,
    [CalendarWeekNumberInYear]              NUMERIC (2)  NOT NULL,
    [CalendarMonthName]                     VARCHAR (9)  NOT NULL,
    [CalendarMonthAbbreviation]             VARCHAR (3)  NOT NULL,
    [CalendarNextMonthName]                 VARCHAR (9)  NOT NULL,
    [CalendarMonthNumberInYear]             NUMERIC (2)  NOT NULL,
    [CalendarQuarterNumber]                 NUMERIC (1)  NOT NULL,
    [CalendarQuarterName]                   VARCHAR (3)  NOT NULL,
    [CalendarYear]                          NUMERIC (4)  NOT NULL,
    [PriorYearDate]                         DATETIME     NOT NULL,
    [PriorYearDayNumberInCalendarWeek]      NUMERIC (1)  NOT NULL,
    [PriorYearDayNumberInCalendarMonth]     NUMERIC (2)  NOT NULL,
    [PriorYearDayNumberInCalendarQuarter]   NUMERIC (3)  NOT NULL,
    [PriorYearDayNumberInCalendarYear]      NUMERIC (3)  NOT NULL,
    [PriorYearCalendarWeekNumberInYear]     NUMERIC (2)  NOT NULL,
    [PriorYearCalendarYear]                 NUMERIC (4)  NOT NULL,
    [CalendarMonthStartingDate]             DATETIME     NOT NULL,
    [CalendarPriorMonthStartingDate]        DATETIME     NOT NULL,
    [CalendarNextMonthStartingDate]         DATETIME     NOT NULL,
    [CalendarMonthEndingDate]               DATETIME     NOT NULL,
    [CalendarPriorMonthEndingDate]          DATETIME     NOT NULL,
    [CalendarNextMonthEndingDate]           DATETIME     NOT NULL,
    [MonthStartingDimDateKey]               INT          NOT NULL,
    [PriorMonthStartingDimDateKey]          INT          NOT NULL,
    [NextMonthStartingDimDateKey]           INT          NOT NULL,
    [MonthEndingDimDateKey]                 INT          NOT NULL,
    [PriorMonthEndingDimDateKey]            INT          NOT NULL,
    [NextMonthEndingDimDateKey]             INT          NOT NULL,
    [FullDateNumericDescription]            VARCHAR (10) NOT NULL,
    [YearMonthDescription]                  VARCHAR (16) NOT NULL,
    [NumberOfDaysInMonthForDSSR]            TINYINT      NOT NULL,
    [DayNumberInCalendarMonthForDSSR]       TINYINT      NOT NULL,
    [PayPeriodCode]                         CHAR (9)     NULL,
    [PayPeriodInMonth]                      CHAR (12)    NULL,
    [PayPeriodFullDescription]              VARCHAR (50) NULL,
    [PayPeriodFirstDayFlag]                 CHAR (1)     NULL,
    [PayPeriodLastDayFlag]                  CHAR (1)     NULL,
    [FourDigitYearDashTwoDigitMonth]        CHAR (7)     NOT NULL,
    [NextDayDimDateKey]                     INT          NULL,
    [PeriodCode]                            VARCHAR (6)  NOT NULL,
    [StandardDateDescription]               VARCHAR (12) NOT NULL,
    [PriorDayDimDateKey]                    INT          NOT NULL,
    [MonthDescriptionYear]                  VARCHAR (14) NOT NULL,
    [FourDigitYearTwoDigitMonthTwoDigitDay] CHAR (8)     NOT NULL,
    [InsertedDateTime]                      DATETIME     DEFAULT (getdate()) NOT NULL,
    [InsertUser]                            VARCHAR (50) DEFAULT (suser_name()) NOT NULL,
    [BatchID]                               INT          NOT NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_ReportDimDateKey]
    ON [dbo].[ReportDimDate]([DimDateKey] ASC) WITH (FILLFACTOR = 90);


GO
CREATE NONCLUSTERED INDEX [IX_ReportDimDate]
    ON [dbo].[ReportDimDate]([CalendarDate] ASC) WITH (FILLFACTOR = 100, DATA_COMPRESSION = PAGE);

