using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceProcess;
using System.Text;

namespace NEPortalLogUploader
{
    public partial class NEPLogUploaderService : ServiceBase
    {
        public NEPLogUploaderService()
        {
            InitializeComponent();
        }

        protected override void OnStart(string[] args)
        {
            if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
            {
                EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                EventLog.CreateEventSource(eventData);
            }
            EventLog.WriteEntry(LogUploadManager.strSource, "NE Portal Log Upload Manager has started managing log uploads. Using configuration settings defined in: " + LogUploadManager.ConfigFilePath,
                EventLogEntryType.Information, 1982);
            LogUploadManager.StartUploadManager();
        }

        protected override void OnStop()
        {
            if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
            {
                EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                EventLog.CreateEventSource(eventData);
            }
            EventLog.WriteEntry(LogUploadManager.strSource, "NE Portal Log Upload Manager has Stopped managing log uploads. Service stopped by user.",
                EventLogEntryType.Information, 1987);
            LogUploadManager.StopUploadManager();
        }
    }
}
