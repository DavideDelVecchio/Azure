﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using Microsoft.PowerBI.Api.V1;
using Microsoft.PowerBI.Security;
using Microsoft.Rest;
using ISVWebApp.Models;
using System.Configuration;
using System.Threading.Tasks;
using System.Security.Claims;

namespace ISVWebApp.Controllers
{
    [Authorize]
    public class DashboardController : Controller
    {
        private readonly string workspaceCollection;
        private readonly string workspaceId;
        private readonly string accessKey;
        private readonly string apiUrl;

        public DashboardController()
        {
            this.workspaceCollection = ConfigurationManager.AppSettings["powerbi:WorkspaceCollection"];
            this.workspaceId = ConfigurationManager.AppSettings["powerbi:WorkspaceId"];
            this.accessKey = ConfigurationManager.AppSettings["powerbi:AccessKey"];
            this.apiUrl = ConfigurationManager.AppSettings["powerbi:ApiUrl"];
        }

        public ActionResult Reports()
        {
            using (var client = this.CreatePowerBIClient())
            {
                var reportsResponse = client.Reports.GetReports(this.workspaceCollection, this.workspaceId);

                var viewModel = new ReportsViewModel
                {
                    Reports = reportsResponse.Value.ToList()
                };

                return View(viewModel);
            }
        }

        public async Task<ActionResult> Report(string reportId = "")
        {
            string tenantID = ClaimsPrincipal.Current.FindFirst("http://schemas.microsoft.com/identity/claims/tenantid").Value;
            string reportName = "AdventureWorks"; // Startup.tenantODataMap[tenantID][1];
            using (var client = this.CreatePowerBIClient())
            {
                var reportsResponse = await client.Reports.GetReportsAsync(this.workspaceCollection, this.workspaceId);
                var report = reportsResponse.Value.FirstOrDefault(r => (r.Id == reportId || r.Name == reportName));
                var embedToken = PowerBIToken.CreateReportEmbedToken(this.workspaceCollection, this.workspaceId, report.Id);

                var viewModel = new ReportViewModel
                {
                    Report = report,
                    AccessToken = embedToken.Generate(this.accessKey)
                };
                return View(viewModel);
            }
        }

        private IPowerBIClient CreatePowerBIClient()
        {
            var credentials = new TokenCredentials(accessKey, "AppKey");
            var client = new PowerBIClient(credentials)
            {
                BaseUri = new Uri(apiUrl)
            };

            return client;
        }
    }
}