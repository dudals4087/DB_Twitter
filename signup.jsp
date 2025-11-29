<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // [기존 로직 유지] 세션 확인
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    String initials = "G";
    if (currentUser != null && currentUser.length() > 0) {
        initials = currentUser.substring(0, 1).toUpperCase();
    }

    String signMsg = null;
    String errorMsg = null;
    boolean signSuccess = false;

    // [기존 로직 유지] 회원가입 처리
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String uid = request.getParameter("user_id");
        String pwd = request.getParameter("pwd");
        String phone = request.getParameter("phone_number"); // DB 컬럼명 확인 완료

        if (uid == null || uid.trim().isEmpty() ||
            pwd == null || pwd.trim().isEmpty() ||
            phone == null || phone.trim().isEmpty()) {

            signMsg = "아이디, 비밀번호, 전화번호를 모두 입력해 주세요";
        } else {
            uid = uid.trim();
            pwd = pwd.trim();
            phone = phone.trim();

            try {
                // 1. 아이디 중복 체크
                boolean idExists = false;
                String checkIdSql = "SELECT 1 FROM users WHERE user_id = ?";
                try (PreparedStatement ps = con.prepareStatement(checkIdSql)) {
                    ps.setString(1, uid);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) idExists = true;
                    }
                }

                if (idExists) {
                    signMsg = "이미 사용 중인 아이디입니다";
                } else {
                    // 2. 전화번호 중복 체크
                    boolean phoneExists = false;
                    String checkPhoneSql = "SELECT 1 FROM users WHERE phone_number = ?";
                    try (PreparedStatement ps = con.prepareStatement(checkPhoneSql)) {
                        ps.setString(1, phone);
                    try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) phoneExists = true;
                        }
                    }

                    if (phoneExists) {
                        signMsg = "이미 다른 계정에 등록된 전화번호입니다";
                    } else {
                        // 3. 사용자 정보 저장 (INSERT)
                        String insSql = "INSERT INTO users (user_id, pwd, phone_number) VALUES (?, ?, ?)";
                        try (PreparedStatement ps = con.prepareStatement(insSql)) {
                            ps.setString(1, uid);
                            ps.setString(2, pwd);
                            ps.setString(3, phone);
                            int n = ps.executeUpdate();
                            if (n > 0) {
                                signSuccess = true;
                                signMsg = "회원가입이 완료되었습니다! 로그인 페이지에서 로그인해 주세요.";
                            } else {
                                signMsg = "회원가입에 실패했습니다.";
                            }
                        }
                    }
                }
            } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
                signMsg = "아이디 또는 전화번호가 이미 사용 중입니다";
            } catch (Exception e) {
                e.printStackTrace();
                errorMsg = "회원가입 처리 중 오류가 발생했습니다.";
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>회원가입 / Twitter</title>
    <link rel="stylesheet" href="style.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@800&display=swap" rel="stylesheet">
</head>
<body class="login-body">

    <div class="login-container">
        <div class="login-left">
            <i class="fa-brands fa-twitter big-logo"></i>
        </div>

        <div class="login-right">
            <div class="login-content" style="max-width: 450px;">
                
                <i class="fa-brands fa-twitter mobile-logo"></i>

                <h2 class="heading-2" style="margin-bottom: 30px; font-size: 30px;">계정을 생성하세요</h2>

                <form method="post" action="signup.jsp" class="login-form" style="max-width: 100%;">
                    
                    <div class="form-field">
                        <input type="text" name="user_id" class="login-input" placeholder="아이디" required>
                    </div>
                    
                    <div class="form-field">
                        <input type="password" name="pwd" class="login-input" placeholder="비밀번호" required>
                    </div>

                    <div class="form-field">
                        <input type="text" name="phone_number" class="login-input" placeholder="휴대폰 번호 (예: 010-1234-5678)" required>
                    </div>

                    <button type="submit" class="btn-login-submit" style="background-color: #0f1419; margin-top: 20px;">
                        가입하기
                    </button>
                    <% if (signMsg != null) { 
                        // 자바에서 '어떤 디자인을 쓸지' 이름만 결정합니다
                        String msgClass = "msg-box " + (signSuccess ? "msg-ok" : "msg-err");
                    %>
                        <div class="<%= msgClass %>">
                            <%= signMsg %>
                        </div>
                    <% } %>

                    <% if (errorMsg != null) { %>
                        <div class="msg-box msg-err">
                            <%= errorMsg %>
                        </div>
                    <% } %>
                    

                </form>

                <div class="signup-prompt" style="text-align: center; margin-top: 30px;">
                    <p style="font-size: 15px; font-weight: 400; color: #536471;">이미 계정이 있으신가요?</p>
                    <a href="login.jsp" class="btn-signup-outline" style="border: none; color: #1d9bf0; padding: 10px; font-size: 15px;">로그인</a>
                </div>

            </div>
        </div>
    </div>

</body>
</html>
<%
    if (con != null) {
        try { con.close(); } catch (Exception ignore) {}
    }
%>