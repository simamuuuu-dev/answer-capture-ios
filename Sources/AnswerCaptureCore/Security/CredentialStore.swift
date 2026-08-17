import Foundation
import Security

public enum CredentialError: Error, Sendable { case unavailable(OSStatus); case invalidData }
public actor CredentialStore {
    private let service: String; private let account: String
    public init(service: String = "com.example.answercapture", account: String = "viewer-token") { self.service=service; self.account=account }
    public func setToken(_ token: String?) throws { var q: [String:Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:service, kSecAttrAccount as String:account]; SecItemDelete(q as CFDictionary); guard let token else { return }; q[kSecValueData as String] = Data(token.utf8); let s=SecItemAdd(q as CFDictionary,nil); guard s == errSecSuccess else { throw CredentialError.unavailable(s) } }
    public func token() throws -> String? { let q:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]; var result: CFTypeRef?; let s=SecItemCopyMatching(q as CFDictionary,&result); if s == errSecItemNotFound { return nil }; guard s == errSecSuccess else { throw CredentialError.unavailable(s) }; guard let d=result as? Data, let token=String(data:d,encoding:.utf8) else { throw CredentialError.invalidData }; return token }
}
