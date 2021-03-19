// This file contains your Data Connector logic
section Yandex;

[DataSource.Kind="Yandex", Publish="Yandex.Publish"]
shared Yandex.Direct = Value.ReplaceType(Yandex.Data, FuncType);

FuncType = type function (
      login  as (type text meta [
        Documentation.FieldCaption = "Login:",
        Documentation.FieldDescription = "Enter your Yandex.Direct login.",
        Documentation.SampleValues = {"mylogin"}
    ]),
     
     columns  as (type text meta [
        Documentation.FieldCaption = "Columns (separated by commas):",
        Documentation.FieldDescription = "Enter your table columns you want to get in the report (separated by commas).",
        Documentation.SampleValues = {"Date,CampaignName,CampaignId,Impressions,Clicks,Cost"}
    ]),
    start as (type text meta [
        Documentation.FieldCaption = "Start date:",
        Documentation.FieldDescription = "Enter the first date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"2020-02-28"}
    ]),
     end as (type text meta [
        Documentation.FieldCaption = "End date:",
        Documentation.FieldDescription = "Enter the last date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"yesterday"}
    ]),
     delay as (type nullable text meta [
        Documentation.FieldCaption = "Delay (sec):",
        Documentation.FieldDescription = "Enter the delay between requests.",
        Documentation.SampleValues = {"10"}
    ]),
      goals as (type nullable text meta [
        Documentation.FieldCaption = "Goals:",
        Documentation.FieldDescription = "Goals list",
        Documentation.SampleValues = {"12345,01234,76543"}
    ]),
      model as (type nullable text meta [
        Documentation.FieldCaption = "Attribution model:",
        Documentation.FieldDescription = "Attribution model",
         Documentation.AllowedValues = { "FC", "LC", "LSC", "LYDC"}
    ])

    )
    as table meta [
        Documentation.Name = "Yandex.Direct Function",
        Documentation.LongDescription = 
        "Created to get data from Yandex.Direct service. 
        Use all dimensions and metrics except ""ImpressionShare"".
        While using ""Query"" parameter, connector will turn into SEARCH_QUERY_PERFORMANCE_REPORT mode.
        Read about this mode in the last example below. You can get Query stat for the last 180 days.
        Get the full list of dimensions and metrics in the last example below.",
        Documentation.Examples = {
        [
            Description = "Returns Impressions,Clicks,Cost by Date and Campaigns.",
            Code = "Yandex.Direct(""y.director"",""Date,CampaignName,CampaignId,Impressions,Clicks,Cost"",""2020-02-20"",""yesterday"", null, null)",
            Result = "Table with 6 columns"
        ],
        [
            Description = "Returns conversions on goal №1234567 (first click attribution) by Keyword and Device.",
            Code = "Yandex.Direct(""y.director"",""Criterion,Device,Conversions"",""150daysAgo"",""today"", ""12345,23456,34567"",""LYDC"")",
            Result ="Table with 5 columns: Criterion,Device and 3 goal conversions"
        ],
        [
            Description = "Copy this url to know about all dimensions, metrics and modes:",
            Code = "https://yandex.ru/dev/direct/doc/reports/report-format-docpage/",
            Result = "https://yandex.ru/dev/direct/doc/reports/fields-list-docpage/"
        ]
        }
    ];


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1000;
windowHeight = 800;


Yandex.Data = (login as text,  columns as text,   start as text,  end as text, delay as nullable text,   goals as nullable text,  model as nullable text)=>
    let
    goals2=if goals=null then "" else goals,
    model2=if model=null then "" else model,
    gam = if Text.Trim(goals2&model2)<>"" then [Goals=Text.Split(goals2,","),AttributionModels ={model2} ] else [],
    fields=Text.Split(Text.Replace(columns," ",""), ","),
    report_type = 
        if List.Contains(fields,"Query") then "SEARCH_QUERY_PERFORMANCE_REPORT" 
        else if List.Contains(fields,"ImpressionReach") then "REACH_AND_FREQUENCY_PERFORMANCE_REPORT" 
        else "CUSTOM_REPORT",
    data = Json.FromValue([params= gam & [SelectionCriteria= [DateFrom= date_func(start),DateTo=date_func(end)],
    FieldNames= fields,
    Page = [Limit = 5000000],
    ReportName= 
    if end = "today" then login&columns&date_func(start)&date_func(end)&goals2&model2&Text.From(Time.Hour(DateTime.LocalNow())) 
    else login&columns&date_func(start)&date_func(end)&goals2&model2,

    ReportType= report_type, DateRangeType= "CUSTOM_DATE", Format= "TSV", IncludeVAT= "YES",IncludeDiscount= "NO"]]),
    headers = [#"Client-Login" = login, #"Authorization"="Bearer "& Extension.CurrentCredential()[access_token],  #"processingMode"="offline", #"Accept-Language"="en", #"Content-Type"="application/json; charset = utf-8"],
    de = if delay = null then 20 else Number.From(delay),
    web1 =web_func(data, headers),
    web2=retry_func(web1,data, headers,5 ),
    web3=retry_func(web2,data, headers,10 ),
    web4=retry_func(web3,data, headers,de ),
    web5=retry_func(web4,data, headers,de ),
    web6=retry_func(web5,data, headers,de ),
    web7=retry_func(web6,data, headers,de ),
    web8=retry_func(web7,data, headers,de ),
    web9=retry_func(web8,data, headers,de ),
    web10=retry_func(web9,data, headers,de ),
    web11=retry_func(web10,data, headers,de ),
    web12=retry_func(web11,data, headers,de ),
    web13=retry_func(web12,data, headers,de ),
    web=retry_func(web13,data, headers,de ),
    final = 
    if  Table.RowCount(web)=1 then try Json.Document(web{0}[Column1])[error][error_string]&": "&Json.Document(web{0}[Column1])[error][error_detail] otherwise "Unknown error"
    else if Table.RowCount(web)=0 then "The response timeout is exceeded. Your report will be available in a minute!"
    else try good(web) otherwise "Can't get the final report. Try again!"
    
in
  final;



web_func= (data,headers)=>
    let
    web = Function.InvokeAfter(()=>Web.Contents("https://api.direct.yandex.com/", [Content = data, IsRetry = false, Headers = headers, ManualStatusHandling = {404, 400,500,401,402,403,501,502,503,504,505}, RelativePath = "json/v5/reports"]),#duration(0,0,0,2)),       
    col = Table.FromColumns({Lines.FromBinary(web, null, null, 65001)})
    in col;


web_retry_func= (data,headers)=>
    let
    web =  Function.InvokeAfter(()=>Web.Contents("https://api.direct.yandex.com/", [Content = data, IsRetry = true, Headers = headers, ManualStatusHandling = {404, 400,500,401,402,403,501,502,503,504,505}, RelativePath = "json/v5/reports"]),#duration(0,0,0,3)),       
    col = Table.FromColumns({Lines.FromBinary(web, null, null, 65001)})
    in col;


retry_func=(web, data, headers, sec)=>
     if Table.RowCount(web)=0 then Function.InvokeAfter(()=> web_retry_func(data, headers), #duration(0,0,0,sec)) else web;
   


date_func= (dat)=>
       if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
       else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
       else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
       else dat;


good=(web)=>
    let
    fieldList = Text.Split(Table.FirstN(Table.Skip(web, 1),1){0}[Column1],"#(tab)"),
    a=Table.PromoteHeaders( Table.SplitColumn(Table.SelectRows(Table.Skip(web, 1), each not Text.Contains([Column1], "Total rows")), "Column1", Splitter.SplitTextByDelimiter("#(tab)", QuoteStyle.Csv), fieldList )),
    b=try Table.TransformColumns(Table.TransformColumnTypes(a,{{"Cost", type number}}), {{"Cost", each _ / 1000000, type number}}) otherwise a,
    type2 =try  Table.TransformColumnTypes(b,{{"Date", type date}}) otherwise b,
    type3 =try Table.TransformColumnTypes(type2 ,{ {"Clicks", Int64.Type}}) otherwise type2 ,
    type4 =try Table.TransformColumnTypes(type3 ,{ {"Impressions", Int64.Type}}) otherwise type3 

    in  type4;


// Data Source Kind description
Yandex = [
    TestConnection = (dataSourcePath) => 
        { 
        "Yandex.Direct",
        Json.Document(dataSourcePath)[login],
        Json.Document(dataSourcePath)[columns],
        Json.Document(dataSourcePath)[start],
        Json.Document(dataSourcePath)[end],
        Json.Document(dataSourcePath)[delay]?,
        Json.Document(dataSourcePath)[goals]?,
        Json.Document(dataSourcePath)[model]?
        },
    Authentication = [
        
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
         //  Refresh=Refresh,
         // Logout=Logout,
            Label = "Log In"
            ]
    ],
    Label = "Yandex Connection"
];

// https://oauth.yandex.ru/authorize?response_type=code&client_id=5240a313fe8a4e2a92449b35cf09b64e

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = "https://oauth.yandex.ru/authorize?" & Uri.BuildQueryString([
            response_type="code",
            client_id="5240a313fe8a4e2a92449b35cf09b64e",
            state = state,
            force_confirm="yes",
            redirect_uri = redirect_uri
            ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = "Hello"
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        Parts = Uri.Parts(callbackUri)[Query]
    in
        TokenMethod(Text.From(Parts[code]));
        
    




TokenMethod = (code ) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/token", [IsRetry=false, ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type ="authorization_code",
                client_id="5240a313fe8a4e2a92449b35cf09b64e",
                code = code,
                client_secret = "3fb1af1bb906491b9751cfaf6f04f9d0",
                redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        Body;

Refresh = (resourceUrl, refresh_token) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/token", [IsRetry=false, ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type ="refresh_token",
                refresh_token =refresh_token,
                client_id="5240a313fe8a4e2a92449b35cf09b64e",
                client_secret = "3fb1af1bb906491b9751cfaf6f04f9d0",
                redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        Body;

Logout = (token ) =>
    let
         Response = Web.Contents("https://oauth.yandex.ru/revoke_token", [ ManualStatusHandling={400},
                Content = Text.ToBinary(Uri.BuildQueryString([
                access_token=if token = null then "" else token,
                client_id="5240a313fe8a4e2a92449b35cf09b64e",
                client_secret = "3fb1af1bb906491b9751cfaf6f04f9d0"
              //  device_id="0",
                //redirect_uri = redirect_uri
                ])),
                Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Body = Json.Document(Response)
    in
        if Body[status]?="ok" then Body else [status="ne ok"];





// Data Source UI publishing description
Yandex.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "Yandex Direct Connector", "Help" },
    LearnMoreUrl = "https://www.youtube.com/channel/UCqSLNYLN_3mf6nA1Xf7fu1g",
    SourceImage = Yandex.Icons,
    SourceTypeImage = Yandex.Icons
];

Yandex.Icons = [
    Icon16 = { Extension.Contents("Yandex16.png"), Extension.Contents("Yandex20.png"), Extension.Contents("Yandex24.png"), Extension.Contents("Yandex32.png") },
    Icon32 = { Extension.Contents("Yandex32.png"), Extension.Contents("Yandex40.png"), Extension.Contents("Yandex48.png"), Extension.Contents("Yandex64.png") }
];
