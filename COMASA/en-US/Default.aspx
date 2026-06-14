<?xml version="1.0" encoding="UTF-8"?>
<% @Page Language="C#" Debug="false" ResponseEncoding="utf-8" ContentType="text/xml" Async="true"%>
<% @Import Namespace="System.Globalization" %>
<% @Import Namespace="System.Web.Configuration" %>
<% @Import Namespace="System.Security" %>
<% @Import Namespace="System.Threading.Tasks" %>
<% @Import Namespace="System.Security.Principal" %>
<% @Import Namespace="Microsoft.TerminalServices.Publishing.Portal.FormAuthentication" %>
<% @Import Namespace="Microsoft.TerminalServices.Publishing.Portal" %>
<% @Import Namespace="System.Web.Security.AntiXss" %>
<script runat="server">

    //
    // Customizable Text
    //
    string L_CompanyName_Text = "COMASA RemoteApp";

    //
    // Localizable Text
    //
    const string L_RemoteAppProgramsLabel_Text = "RemoteApp e Áreas de Trabalho";
    const string L_DesktopTab_Text = "Conectar a um PC remoto";
    const string L_BadFolderErrorTitle_Text = "A pasta não existe. Redirecionando...";
    const string L_BadFolderErrorBody_Text = "Você tentou carregar uma pasta inexistente. Em instantes, será redirecionado para a pasta principal.";
    const string L_RenderFailTitle_Text = "Erro: não foi possível exibir o portal RemoteApp COMASA";
    const string L_RenderFailP1_Text = "Ocorreu um erro inesperado que impede a exibição correta desta página.";
    const string L_RenderFailP2_Text = "Exibir esta página no Internet Explorer com a Configuração de Segurança Reforçada habilitada pode causar esse erro.";
    const string L_RenderFailP3_Text = "Tente carregar esta página sem a Configuração de Segurança Reforçada habilitada. Se o erro continuar, contate o administrador.";

    //
    // Page Variables
    //
    public string sHelpSourceServer, sLocalHelp, sRDCInstallUrl, strWorkspaceName;
    public Uri baseUrl, stylesheetUrl, renderFailCssUrl;
    public bool bShowPublicCheckBox = false, bPrivateMode = false, bRTL = false;
    public int SessionTimeoutInMinutes = 0;
    public bool bShowOptimizeExperience = false, bOptimizeExperienceState = false;
    public AuthenticationMode eAuthenticationMode = AuthenticationMode.None;
    public string strTicketName = "";
    public string strDomainUserName = "", strUserIdentity = "";
    public string strAppFeed;
    public string strPrivacyUrl;

    public WorkspaceInfo objWorkspaceInfo = null;

    protected void Page_PreInit(object sender, EventArgs e)
    {
        RegisterAsyncTask(new PageAsyncTask(GetAppsAsync));
        ExecuteRegisteredAsyncTasks();
    }

    private async Task GetAppsAsync()
    {

        // gives us https://<hostname>[:port]/rdweb/pages/<lang>/
        baseUrl = new Uri(new Uri(RequestHelper.GetOriginalRequestUri(Request), RequestHelper.GetRequestFilePath(Request)), ".");
        TraceWrite.TraceVerboseNoContext("baseUrl.AbsoluteUri: {0}", baseUrl.AbsoluteUri);
        TraceWrite.TraceVerboseNoContext("baseUrl.AbsolutePath: {0}", baseUrl.AbsolutePath);

        strPrivacyUrl = await PageContentsHelper.GetPrivacyLinkAsync();

        try
        {
            string strShowOptimzeExperienceValue = ConfigurationManager.AppSettings["ShowOptimizeExperience"];
            if ( String.IsNullOrEmpty(strShowOptimzeExperienceValue) == false )
            {
                if ( strShowOptimzeExperienceValue.Equals( System.Boolean.TrueString, StringComparison.OrdinalIgnoreCase) )
                {
                    bShowOptimizeExperience = true;
                    string strOptimizeExperienceStateValue = ConfigurationManager.AppSettings["OptimizeExperienceState"];
                    if ( String.IsNullOrEmpty(strOptimizeExperienceStateValue) == false )
                    {
                        if ( strOptimizeExperienceStateValue.Equals( System.Boolean.TrueString, StringComparison.OrdinalIgnoreCase) )
                        {
                            bOptimizeExperienceState = true;
                        }
                    }
                }
            }
        }
        catch (Exception objException)
        {
        }

        AuthenticationSection objAuthenticationSection = ConfigurationManager.GetSection("system.web/authentication") as AuthenticationSection;
        if ( objAuthenticationSection  != null )
        {
            eAuthenticationMode = objAuthenticationSection.Mode;
        }

        if ( eAuthenticationMode == AuthenticationMode.Forms )
        {
            if ( HttpContext.Current.User.Identity.IsAuthenticated == false )
            {
                bool fQueryContainsReturnUrl = false;
                if (Request.QueryString != null)
                {
                    NameValueCollection objQueryString = Request.QueryString;
                    fQueryContainsReturnUrl = (objQueryString["ReturnUrl"] != null);
                }

                string strQueryString;
                if (fQueryContainsReturnUrl)
                {
                    strQueryString = Request.Url.Query;
                }
                else
                {
                    string strReturnUrlQueryParam = "ReturnUrl=" + RequestHelper.GetOriginalRequestUri(Request).AbsolutePath;
                    if (String.IsNullOrEmpty(Request.Url.Query))
                    {
                        strQueryString = "?" + strReturnUrlQueryParam;
                    }
                    else
                    {
                        strQueryString = Request.Url.Query + "&" + strReturnUrlQueryParam;
                    }
                }

                Response.Redirect(new Uri(baseUrl, "login.aspx" + strQueryString).AbsoluteUri);
            }

            TSFormAuthTicketInfo objTSFormAuthTicketInfo = new TSFormAuthTicketInfo(HttpContext.Current);
            strUserIdentity = objTSFormAuthTicketInfo.UserIdentity;
            bPrivateMode = objTSFormAuthTicketInfo.PrivateMode;
            strDomainUserName = objTSFormAuthTicketInfo.DomainUserName;

            if ( bPrivateMode == true )
            {
                try
                {
                    string strPrivateModeSessionTimeoutInMinutes = ConfigurationManager.AppSettings["PrivateModeSessionTimeoutInMinutes"].ToString();
                    SessionTimeoutInMinutes = Int32.Parse(strPrivateModeSessionTimeoutInMinutes);
                }
                catch (Exception objException)
                {
                    Console.WriteLine("\nException : " + objException.Message);
                    SessionTimeoutInMinutes = 240;
                }
            }
            else
            {
                try
                {
                    string strPublicModeSessionTimeoutInMinutes = ConfigurationManager.AppSettings["PublicModeSessionTimeoutInMinutes"].ToString();
                    SessionTimeoutInMinutes = Int32.Parse(strPublicModeSessionTimeoutInMinutes);
                }
                catch (Exception objException)
                {
                    Console.WriteLine("\nException : " + objException.Message);
                    SessionTimeoutInMinutes = 20;
                }
            }
        }
        else if ( eAuthenticationMode == AuthenticationMode.Windows )
        {
            bShowPublicCheckBox = true;
            WindowsIdentity identity = (WindowsIdentity)Context.User.Identity;
            strUserIdentity = identity.User.ToString();
        }

        sRDCInstallUrl = ConfigurationManager.AppSettings["rdcInstallUrl"];

        sLocalHelp = ConfigurationManager.AppSettings["LocalHelp"];

        stylesheetUrl = new Uri(baseUrl, "../Site.xsl");
        renderFailCssUrl = new Uri(baseUrl, "../RenderFail.css");

        if ((sLocalHelp != null) && (sLocalHelp == "true"))
            sHelpSourceServer = "./rap-help.htm";
        else
            sHelpSourceServer = "http://go.microsoft.com/fwlink/?LinkId=141038";

        try {
          bRTL = CultureInfo.CurrentUICulture.TextInfo.IsRightToLeft;
        }
        catch( NullReferenceException ) {
        }

        WebFeed tswf = null;
        try
        {
            tswf = new WebFeed(RdpType.Both, true);

            Tuple<string, int> retValues = await tswf.GenerateFeedAsync(
                            strUserIdentity,
                            FeedXmlVersion.Win8,
                            (Request.PathInfo.Length > 0) ? Request.PathInfo : "/",
                            false);

            strAppFeed = retValues.Item1;
        }
        catch (WorkspaceUnknownFolderException)
        {
            BadFolderRedirect();
        }
        catch (InvalidTenantException)
        {
            Response.StatusCode = 404;
            Response.End();
        }
        catch (WorkspaceUnavailableException wue)
        {
            // This exception is raised when we cannot contact the appropriate sources to obtain the workspace information.
            // This is an edge case that can ocurr e.g. if the cpub server we're pointing to is down and the values are not specified in the Web.config.
            Response.StatusCode = 503;
            Response.End();
        }

        if ( tswf != null )
        {
            objWorkspaceInfo = tswf.GetFetchedWorkspaceInfo();
            if ( objWorkspaceInfo != null )
            {
                strWorkspaceName = objWorkspaceInfo.WorkspaceName;
            }
        }
        if ( String.IsNullOrEmpty(strWorkspaceName ) )
        {
            strWorkspaceName = L_CompanyName_Text;
        }
    }

    protected void Page_Init(object sender, EventArgs e)
    {
        Response.Cache.SetCacheability(HttpCacheability.NoCache);
    }

    private void BadFolderRedirect()
    {
        Response.ContentType = "text/html";
        Response.Write(
@"<html>
   <head>
     <meta http-equiv=""refresh"" content=""10;url=" + Request.FilePath + @"""/>
     <title>" + L_BadFolderErrorTitle_Text + @"</title>
   </head>
   <body>
     <p id=""BadFolder1"">" + L_BadFolderErrorBody_Text + @"</p>
   </body>
 </html>");
        Response.End();
    }

</script>
<%="<?xml-stylesheet type=\"text/xsl\" href=\"" + SecurityElement.Escape(stylesheetUrl.AbsoluteUri) + "\"?>"%>
<%="<?xml-stylesheet type=\"text/css\" href=\"" + SecurityElement.Escape(renderFailCssUrl.AbsoluteUri) + "\"?>"%>
<RDWAPage
    helpurl="<%=sHelpSourceServer%>"
    domainuser="<%=SecurityElement.Escape(strDomainUserName)%>"
    workspacename="<%=AntiXssEncoder.XmlAttributeEncode(strWorkspaceName)%>"
    baseurl="<%=SecurityElement.Escape(baseUrl.AbsoluteUri)%>"
    privacyurl="<%=AntiXssEncoder.XmlAttributeEncode(strPrivacyUrl)%>"
    >
    <RenderFailureMessage>
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
                <title><%=L_RenderFailTitle_Text%></title>
            </head>
            <body>
                <h1><%=L_RenderFailTitle_Text%></h1>
                <p><%=L_RenderFailP1_Text%></p>
                <p><%=L_RenderFailP2_Text%></p>
                <p><%=L_RenderFailP3_Text%></p>
            </body>
        </html>
    </RenderFailureMessage>
    <HeaderJS>
        bFormAuthenticationMode = false;
    <%  if ( eAuthenticationMode == AuthenticationMode.Forms ) { %>
        bFormAuthenticationMode = true;
    <%  } %>
        iSessionTimeout = parseInt("<%=SessionTimeoutInMinutes%>");
    </HeaderJS>
    <BodyAttr
        onload="onPageload(event)"
        onunload="onPageUnload(event)"
        onmousedown="onUserActivity(event)"
        onmousewheel="onUserActivity(event)"
        onscroll="onUserActivity(event)"
        onkeydown="onUserActivity(event)" />
    <PostHtmlLoadJS>
        onAuthenticatedPageload();
    </PostHtmlLoadJS>
    <NavBar
    <% if ( eAuthenticationMode == AuthenticationMode.Forms ) {  %>
        showsignout="true"
    <% } %>
        activetab="PORTAL_REMOTE_PROGRAMS"
    >
        <Tab id="PORTAL_REMOTE_PROGRAMS" href="Default.aspx"><%=L_RemoteAppProgramsLabel_Text%></Tab>
<%
    if (ConfigurationManager.AppSettings["ShowDesktops"].ToString() == "true")
    {
%>
        <Tab id="PORTAL_REMOTE_DESKTOPS" href="Desktops.aspx"><%=L_DesktopTab_Text%></Tab>
<%
    }
%>

    </NavBar>
    <Style>
      .tswa_appboard {width:850px;}
      .tswa_ShowOptimizeExperienceShiftedUp
      {
        position:absolute;
        left:10px;
        top:397px;
        width:850px;
        height:20px;
        background-color:white;
      }

      #PORTAL_REMOTE_DESKTOPS
      {
          display:none;
      }
<%
    if ( bShowPublicCheckBox )
    {
%>
      .tswa_ShowOptimizeExperience
      {
        position:absolute;
        left:10px;
        top:445px;
        width:850px;
        height:20px;
        background-color:white;
      }
<%
    }
    else
    {
%>
      .tswa_ShowOptimizeExperience
      {
        position:absolute;
        left:10px;
        top:462px;
        width:850px;
        height:20px;
        background-color:white;
      }
<%
    }
%>
      .tswa_PublicCheckboxMore
      {
        position:absolute;
        left:10px;
        top:417px;
        width:850px;
        height:50px;
        border-top: 1px solid gray;
        background-color:white;
        z-index:4000;
        padding-top:4px;
      }

      .tswa_PublicCheckboxLess
      {
        position:absolute;
        left:10px;
        top:462px;
        width:850px;
        height:20px;
        background-color:white;
      }

<% if (bRTL) { %>
      /* Rules that are specific to RTL language environments */

      .tswa_appboard
      {
        padding-right:10px;
      }

      .tswa_boss, .tswa_folder_boss, .tswa_up_boss
      {
        float:right;
      }

      .tswa_error_icon
      {
        margin-left: 0px;
        padding-left: 0px;
        margin-right:10px;
        padding-right:45px;
      }

      .tswa_error_msg
      {
        margin-left:0px;
        padding-right:0px;
        margin-right:55px;
        padding-left:10px;
      }

<% } %>
    </Style>
    <Style condition="if IE 6">
      .tswa_appdisplay
      {
        background-color:transparent;left:5px;top:0px;height:450px;width:850px;
      }


      .tswa_ShowOptimizeExperienceShiftedUp
      {
        position:absolute;
        left:10px;
        top:415px;
        width:850px;
        height:20px;
        background-color:white;
      }

<%
    if ( bShowPublicCheckBox )
    {
%>
       .tswa_ShowOptimizeExperience
       {
         position:absolute;
         left:10px;
         top:463px;
         width:850px;
         height:20px;
         background-color:white;
       }
<%
    }
    else
    {
%>
       .tswa_ShowOptimizeExperience
       {
         position:absolute;
         left:10px;
         top:480px;
         width:850px;
         height:20px;
         background-color:white;
       }
<%
    }
%>
       .tswa_PublicCheckboxMore
       {
         position:absolute;
         left:10px;
         top:435px;
         width:850px;
         height:50px;
         border-top: 1px solid gray;
         background-color:white;
         z-index:4000;
         padding-top:4px;
       }

       .tswa_PublicCheckboxLess
       {
         position:absolute;
         left:10px;
         top:480px;
         width:850px;
         height:20px;
         background-color:white;
       }
    </Style>
    <Style condition="if gte IE 7">
      .tswa_appdisplay
      {
        background-color:transparent;
        left:5px;
        top:0px;
        height:440px;
        width:850px;
      }

      .tswa_ShowOptimizeExperienceShiftedUp
      {
        position:absolute;
        left:10px;
        top:397px;
        width:850px;
        height:20px;
        background-color:white;
      }
<%
    if ( bShowPublicCheckBox )
    {
%>
      .tswa_ShowOptimizeExperience
      {
        position:absolute;
        left:10px;
        top:445px;
        width:850px;
        height:20px;
        background-color:white;
      }
<%
    }
    else
    {
%>
      .tswa_ShowOptimizeExperience
      {
        position:absolute;
        left:10px;
        top:462px;
        width:850px;
        height:20px;
        background-color:white;
      }
<%
    }
%>
      .tswa_PublicCheckboxMore
      {
        position:absolute;
        left:10px;
        top:417px;
        width:850px;
        height:50px;
        border-top: 1px solid gray;
        background-color:white;
        z-index:4000;
        padding-top:4px;
      }

      .tswa_PublicCheckboxLess
      {
        position:absolute;
        left:10px;
        top:462px;
        width:850px;
        height:20px;
        background-color:white;
      }
    </Style>
    <AppFeed
        showpubliccheckbox="<%=bShowPublicCheckBox.ToString().ToLower()%>"
        privatemode="<%=bPrivateMode.ToString().ToLower()%>"
        showoptimizeexperience="<%=bShowOptimizeExperience.ToString().ToLower()%>"
        optimizeexperiencestate="<%=bOptimizeExperienceState.ToString().ToLower()%>"
        <%
        if (!String.IsNullOrEmpty(sRDCInstallUrl)) {
        %>
        rdcinstallurl="<%=SecurityElement.Escape(sRDCInstallUrl)%>"
        <%
        }
        %>
    >
        <%=strAppFeed%>
    </AppFeed>
</RDWAPage>
