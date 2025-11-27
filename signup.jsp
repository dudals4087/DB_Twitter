<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // 세션에서 로그인 정보 읽기
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

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String uid = request.getParameter("user_id");
        String pwd = request.getParameter("pwd");
        String phone = request.getParameter("phone_number");

        if (uid == null || uid.trim().isEmpty() ||
            pwd == null || pwd.trim().isEmpty() ||
            phone == null || phone.trim().isEmpty()) {

            signMsg = "아이디, 비밀번호, 전화번호를 모두 입력해 주세요";
        } else {
            uid = uid.trim();
            pwd = pwd.trim();
            phone = phone.trim();

            try {
                // 아이디 중복 체크
                boolean idExists = false;
                String checkIdSql = "SELECT 1 FROM users WHERE user_id = ?";
                try (PreparedStatement ps = con.prepareStatement(checkIdSql)) {
                    ps.setString(1, uid);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            idExists = true;
                        }
                    }
                }

                if (idExists) {
                    signMsg = "이미 사용 중인 아이디입니다";
                } else {
                    // 전화번호 중복 체크
                    boolean phoneExists = false;
                    String checkPhoneSql = "SELECT 1 FROM users WHERE phone_number = ?";
                    try (PreparedStatement ps = con.prepareStatement(checkPhoneSql)) {
                        ps.setString(1, phone);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                phoneExists = true;
                            }
                        }
                    }

                    if (phoneExists) {
                        signMsg = "이미 다른 계정에 등록된 전화번호입니다";
                    } else {
                        // 새 사용자 insert
                        String insSql =
                            "INSERT INTO users (user_id, pwd, phone_number) " +
                            "VALUES (?, ?, ?)";
                        try (PreparedStatement ps = con.prepareStatement(insSql)) {
                            ps.setString(1, uid);
                            ps.setString(2, pwd);
                            ps.setString(3, phone);
                            int n = ps.executeUpdate();
                            if (n > 0) {
                                signSuccess = true;
                                signMsg = "회원가입이 완료되었습니다  로그인 페이지에서 방금 만든 아이디로 로그인해 주세요";
                            } else {
                                signMsg = "회원가입에 실패했습니다";
                            }
                        }
                    }
                }
            } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
                signMsg = "아이디 또는 전화번호가 이미 사용 중입니다";
            } catch (Exception e) {
                e.printStackTrace();
                errorMsg = "회원가입 처리 중 오류가 발생했어요";
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>회원가입  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">회원가입</div>
        </div>
        <div class="app-header-right">
            <%
                if (currentUser == null) {
            %>
                <a href="login.jsp" class="icon-btn" title="로그인">👤</a>
                <a href="login.jsp" class="icon-btn" title="설정은 로그인 후 이용 가능">⚙</a>
                <a href="login.jsp" class="icon-btn" title="메시지는 로그인 후 이용 가능">💬</a>
            <%
                } else {
            %>
                <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= initials %></a>
                <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
                <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
            <%
                }
            %>
        </div>
    </header>

    <!-- 회원가입 카드 -->
    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">새 계정 만들기</div>
            <div class="auth-sub">
                TWITTER_DB4에서 사용할 새로운 계정을 등록하세요
            </div>

            <form method="post" action="signup.jsp">
                <div class="form-field">
                    <div class="form-label">아이디</div>
                    <input type="text" name="user_id" class="input-text" placeholder="아이디를 입력하세요">
                </div>
                <div class="form-field">
                    <div class="form-label">비밀번호</div>
                    <input type="password" name="pwd" class="input-text" placeholder="비밀번호를 입력하세요">
                </div>
                <div class="form-field">
                    <div class="form-label">전화번호</div>
                    <input type="text" name="phone_number" class="input-text" placeholder="예  010-xxxx-xxxx">
                </div>

                <button type="submit" class="btn-secondary" style="width:100%; margin-top:4px;">
                    가입하기
                </button>
            </form>

            <a href="login.jsp" class="btn-ghost" style="width:100%; display:inline-block; text-align:center; margin-top:8px;">
                이미 계정이 있나요  로그인하기
            </a>

            <%
                if (signMsg != null) {
            %>
                <div class="msg <%= signSuccess ? "msg-ok" : "msg-err" %>"><%= signMsg %></div>
            <%
                }
                if (errorMsg != null) {
            %>
                <div class="msg msg-err"><%= errorMsg %></div>
            <%
                }
            %>

            <div class="helper-text">
                가입이 완료되면 로그인 페이지에서  
                방금 만든 아이디와 비밀번호로 로그인할 수 있어요
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
