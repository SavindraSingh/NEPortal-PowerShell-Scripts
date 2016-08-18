using System;
using System.Collections.Generic;
using System.Linq;
// Namespace for CloudConfigurationManager
using Microsoft.WindowsAzure.Storage; // Namespace for CloudStorageAccount
using Microsoft.WindowsAzure.Storage.Blob; // Namespace for Blob storage types
using System.Configuration;
using System.Xml.Linq;
using System.Diagnostics;
using System.Threading;
using System.IO;
using System.Windows.Forms;

namespace NEPortalLogUploader
{
    public static class LogUploadManager
    {
        public static string strSource = "NE Portal Log Uploader"; public static string strLog = "Application";
        public static string strMachine = Environment.GetEnvironmentVariable("COMPUTERNAME");
        public static string ConfigFilePath = ConfigurationManager.AppSettings["ConfigurationFilePath"];
        public static string ConfigFolderPath = ConfigurationManager.AppSettings["ConfigurationFolderPath"];
        public static int UploadFrequencyInSeconds = 120;
        static string strStorageAccKey = ""; static string strContainer = ""; static string strStorageAccName = "";
        private static System.Timers.Timer uploadTimer;
        private static bool UploadsCycleActive = false;

        public static void InitialiseLUM()
        {
            if (File.Exists(ConfigFilePath))
            {
                if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
                {
                    EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                    EventLog.CreateEventSource(eventData);
                }
                EventLog.WriteEntry(LogUploadManager.strSource, "Config file found at:" + ConfigFilePath, EventLogEntryType.Information, 1987);

                try
                {
                    // Read configuration and start work
                    XDocument doc = XDocument.Load(ConfigFilePath);

                    Dictionary<string, string> keyValues = doc.Descendants("add").ToDictionary(x => x.Attribute("key").Value,
                                                           x => x.Attribute("value").Value);
                    strContainer = keyValues["Container"];
                    strStorageAccName = keyValues["StorageAccName"];
                    strStorageAccKey = keyValues["StorageAccKey"];
                    if (int.TryParse(keyValues["UploadFrequencySeconds"], out UploadFrequencyInSeconds))
                    {
                        // Update upload interval
                    }
                    else
                    {
                        if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
                        {
                            EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                            EventLog.CreateEventSource(eventData);
                        }
                        EventLog.WriteEntry(LogUploadManager.strSource, "NE Portal Log Upload Manager has encountered an error:" + Environment.NewLine +
                            "Upload frequency value was not in correct format. Please check if " + ConfigFilePath + " has correct values. Then restart the 'NEPortalLogUploader' service.", EventLogEntryType.Error, 1983);
                    }

                    try
                    {
                        uploadTimer = new System.Timers.Timer();
                        uploadTimer.Interval = (int)(TimeSpan.FromSeconds(UploadFrequencyInSeconds).TotalMilliseconds);
                        uploadTimer.Elapsed += new System.Timers.ElapsedEventHandler(uploadTimer_Tick);
                        uploadTimer.AutoReset = false;
                        uploadTimer.Start();
                        UploadsCycleActive = true;
                    }
                    catch (Exception ex)
                    {
                        EventLog.WriteEntry(LogUploadManager.strSource, "Error while setting Timer. Setting up Timer: " + ex.Message,
                                            EventLogEntryType.Error, 1983);
                    }
                }
                catch (Exception ex)
                {
                    if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
                    {
                        EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                        EventLog.CreateEventSource(eventData);
                    }
                    EventLog.WriteEntry(LogUploadManager.strSource, "NE Portal Log Upload Manager has encountered an error while configuring the upload settings:" +
                                        Environment.NewLine + ex.Message, EventLogEntryType.Error, 1983);
                }
            }
            else
            {
                EventLog.WriteEntry(LogUploadManager.strSource, "Missing configuration file at: " + ConfigFilePath + Environment.NewLine + "Place the configuration file at this path and Restart 'NEPortalLogUploader' service for successful uploading of log files.",
                                    EventLogEntryType.Error, 1983);
            }
        }

        static void uploadTimer_Tick(object sender, EventArgs e)
        {
            StartUploading();
            uploadTimer.Interval = (int)(TimeSpan.FromSeconds(UploadFrequencyInSeconds).TotalMilliseconds);
            UploadsCycleActive = true;
            uploadTimer.Start();
        }

        public static void StartUploadManager()
        {
            InitialiseLUM();
        }

        public static void StopUploadManager()
        {
            if (UploadsCycleActive)
            {
                uploadTimer.Stop();
                UploadsCycleActive = false;
            }
        }

        public static void StartUploading()
        {
            try
            {
                // Retrieve storage account from connection string.
                string connectionString = "DefaultEndpointsProtocol=https;AccountName=" + strStorageAccName + ";AccountKey=" + strStorageAccKey;
                CloudStorageAccount storageAccount = CloudStorageAccount.Parse(connectionString);

                // Create the blob client.
                CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();

                // Retrieve reference to a previously created container.
                CloudBlobContainer container = blobClient.GetContainerReference(strContainer);

                // Create or overwrite the "myblob" blob with contents from local file.
                string[] logFiles = Directory.GetFiles(ConfigFolderPath);
                foreach (var file in logFiles)
                {
                    if (file.ToLower().EndsWith(".log"))
                    {
                        if (File.ReadAllText(file).Contains("<#BlobFileReadyForUpload#>"))
                        {
                            // Specify file name for the Blob file
                            string BlobFileName = file.Substring(file.LastIndexOf(@"\") + 1, (file.Length - file.LastIndexOf(@"\")) - 1);
                            CloudBlockBlob blockBlob = container.GetBlockBlobReference(BlobFileName);

                    //        EventLog.WriteEntry(LogUploadManager.strSource, "Uploading file: " + BlobFileName,
                    //EventLogEntryType.Information, 1987);

                            // Upload file to blob
                            blockBlob.UploadFromFile(file);

                            // Delete local copy of the file
                            File.Delete(file);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                if (!EventLog.SourceExists(LogUploadManager.strSource, LogUploadManager.strMachine))
                {
                    EventSourceCreationData eventData = new EventSourceCreationData(LogUploadManager.strSource, LogUploadManager.strLog);
                    EventLog.CreateEventSource(eventData);
                }
                EventLog.WriteEntry(LogUploadManager.strSource, "NE Portal Log Upload Manager has encountered an error while uploading log files:" +
                Environment.NewLine + ex.Message, EventLogEntryType.Error, 1983);
            }
            finally
            {
                GC.Collect();
            }
        }
    }
}
