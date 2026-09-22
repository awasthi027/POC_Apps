import SwiftUI
import SwiftData

struct FileDownloadListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FileDownloadViewModel
    @State private var showAddDownload = false
    
    init() {
        _viewModel = State(initialValue: FileDownloadViewModel())
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.fileDownloads.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("No Downloads")
                            .font(.headline)
                        Text("Add a URL to start downloading files")
                            .foregroundColor(.gray)
                        Button("Add Download") {
                            showAddDownload = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(viewModel.fileDownloads) { download in
                            FileDownloadRowView(download: download, viewModel: viewModel)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteDownload(viewModel.fileDownloads[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddDownload = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddDownload) {
                AddDownloadSheet(
                    viewModel: viewModel,
                    isPresented: $showAddDownload
                )
            }
        }
        .onAppear {
            let dataStore = DataStore(modelContext: modelContext)
            viewModel.setDataStore(dataStore)
        }
    }
}

struct FileDownloadRowView: View {
    let download: FileDownload
    let viewModel: FileDownloadViewModel
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(download.url)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                StatusBadgeView(status: download.status)
            }
            
            if download.status == .downloading || download.status == .paused {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: viewModel.getDownloadProgress(download))
                        .tint(.blue)
                    
                    HStack {
                        Text("\(viewModel.getFormattedFileSize(download.downloadedSize)) / \(viewModel.getFormattedFileSize(download.fileSize))")
                            .font(.caption)
                        Spacer()
                        Text(viewModel.getDownloadProgressPercentage(download))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.secondary)
                }
            } else if download.status == .completed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Completed: \(viewModel.getFormattedFileSize(download.fileSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let path = download.localPath {
                        Button(action: { openFile(at: path) }) {
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            } else if download.status == .failed {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(download.error ?? "Failed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            DownloadActionButtonsView(download: download, viewModel: viewModel)
        }
        .padding(.vertical, 4)
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Trigger refresh by updating the view
        }
    }
    
    private func openFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        UIApplication.shared.open(url)
    }
}

struct StatusBadgeView: View {
    let status: DownloadStatus
    
    var backgroundColor: Color {
        switch status {
        case .pending, .paused: return .gray
        case .downloading: return .blue
        case .completed: return .green
        case .failed, .cancelled: return .red
        }
    }
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

struct DownloadActionButtonsView: View {
    let download: FileDownload
    let viewModel: FileDownloadViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            if download.status == .downloading {
                Button(action: { viewModel.pauseDownload(download) }) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            if download.status == .paused {
                Button(action: { viewModel.resumeDownload(download) }) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
            
            if download.status == .failed || download.status == .pending {
                Button(action: { viewModel.startDownload(download) }) {
                    Label("Start", systemImage: "arrowshape.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            
            if download.status == .downloading || download.status == .paused {
                Button(action: { viewModel.cancelDownload(download) }) {
                    Label("Cancel", systemImage: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            Spacer()
        }
    }
}

struct AddDownloadSheet: View {
    let viewModel: FileDownloadViewModel
    @Binding var isPresented: Bool
    @State private var url = ""
    @State private var fileName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Download Details") {
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                    
                    TextField("File Name", text: $fileName)
                }
            }
            .navigationTitle("Add Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !url.isEmpty && !fileName.isEmpty {
                            viewModel.createDownload(url: url, fileName: fileName)
                            isPresented = false
                        }
                    }
                    .disabled(url.isEmpty || fileName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    FileDownloadListView()
        .modelContainer(for: FileDownload.self, inMemory: true)
}
