<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    // 로그인 체크
    String currentUser = (String) session.getAttribute("currentUser");
    Boolean currentPaid = (Boolean) session.getAttribute("currentUserPaid");
    if (currentPaid == null) currentPaid = false;

    if (currentUser == null) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String initials = currentUser.substring(0, 1).toUpperCase();

    String payMsg = null;
    String errorMsg = null;
    boolean paySuccess = false;

    // POST 요청이면 결제 처리
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String periodStr = request.getParameter("period");

        if (periodStr == null || periodStr.trim().isEmpty()) {
            payMsg = "구독 기간을 선택해 주세요";
        } else {
            periodStr = periodStr.trim();
            try {
                int period = Integer.parseInt(periodStr);

                // 이미 구독 중인지 확인
                String paidFlag = "F";
                try {
                    String qsql = "SELECT paid FROM users WHERE user_id = ?";
                    try (PreparedStatement ps = con.prepareStatement(qsql)) {
                        ps.setString(1, currentUser);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                String pf = rs.getString("paid");
                                if (pf != null) {
                                    paidFlag = pf;
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }

                if ("T".equals(paidFlag)) {
                    payMsg = "이미 구독 회원으로 등록되어 있습니다";
                    paySuccess = false;
                } else {
                    // 구독 insert + users.paid = 'T'
                    try {
                        boolean oldAuto = con.getAutoCommit();
                        con.setAutoCommit(false);
                        try {
                            String pid = "sub" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);

                            String insSql =
                                "INSERT INTO subscriptions (p_id, user_id, period) " +
                                "VALUES (?, ?, ?)";
                            try (PreparedStatement ps = con.prepareStatement(insSql)) {
                                ps.setString(1, pid);
                                ps.setString(2, currentUser);
                                ps.setInt(3, period);
                                ps.executeUpdate();
                            }

                            String upSql =
                                "UPDATE users SET paid = 'T' " +
                                "WHERE user_id = ?";
                            try (PreparedStatement ps = con.prepareStatement(upSql)) {
                                ps.setString(1, currentUser);
                                ps.executeUpdate();
                            }

                            con.commit();
                            con.setAutoCommit(oldAuto);

                            // 세션에도 반영
                            session.setAttribute("currentUserPaid", true);

                            paySuccess = true;
                            payMsg = "구독 결제가 완료되었습니다  이제 아이디 옆에 체크 표시가 표시됩니다";
                        } catch (Exception e2) {
                            con.rollback();
                            throw e2;
                        }
                    } catch (Exception ex) {
                        ex.printStackTrace();
                        errorMsg = "결제 처리 중 오류가 발생했어요";
                    }
                }
            } catch (NumberFormatException nfe) {
                payMsg = "올바른 구독 기간을 선택해 주세요";
            }
        }
    }

    boolean isPaid = currentPaid != null && currentPaid;
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>구독 결제  TWITTER_DB4</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="app-shell">

    <!-- 상단 헤더 -->
    <header class="app-header">
        <div class="app-header-left">
            <a href="main.jsp" class="app-logo">TWITTER_DB4</a>
            <div class="app-logo-sub">구독 결제</div>
        </div>
        <div class="app-header-right">
            <a href="profile.jsp" class="icon-btn" title="내 프로필"><%= initials %></a>
            <a href="settings.jsp" class="icon-btn" title="설정">⚙</a>
            <a href="messages.jsp" class="icon-btn" title="메시지">💬</a>
        </div>
    </header>

    <!-- 가운데 결제 카드 -->
    <div class="center-layout">
        <div class="auth-card">
            <div class="auth-title">TWITTER_DB4 구독</div>
            <div class="auth-sub">
                구독 결제를 진행하면 게시글과 댓글에서  
                아이디 옆에 초록색 체크 표시가 함께 표시됩니다
            </div>

            <div class="form-field">
                <div class="form-label">현재 계정</div>
                <div style="display:flex; align-items:center; gap:8px;">
                    <div class="avatar-sm"><%= initials %></div>
                    <div>
                        <div class="user-name-row">
                            <span><%= currentUser %></span>
                            <%
                                if (isPaid) {
                            %>
                            <span class="badge-check">✓</span>
                            <%
                                }
                            %>
                        </div>
                        <div class="helper-text">
                            이 계정으로 구독 결제가 진행됩니다
                        </div>
                    </div>
                </div>
            </div>

            <form method="post" action="subscribe.jsp" style="margin-top:12px;">
                <div class="form-field">
                    <div class="form-label">구독 기간 선택</div>
                    <select name="period" class="input-text">
                        <option value="">기간을 선택하세요</option>
                        <option value="1">1개월</option>
                        <option value="3">3개월</option>
                        <option value="6">6개월</option>
                        <option value="12">12개월</option>
                    </select>
                </div>

                <!-- 가상 결제 정보 (실제 결제는 안 함, 형식만) -->
                <div class="form-field">
                    <div class="form-label">카드번호</div>
                    <input type="text" class="input-text" placeholder="예  1111-2222-3333-4444" />
                </div>
                <div class="form-field" style="display:flex; gap:8px;">
                    <div style="flex:1;">
                        <div class="form-label">유효기간</div>
                        <input type="text" class="input-text" placeholder="MM/YY" />
                    </div>
                    <div style="width:90px;">
                        <div class="form-label">CVC</div>
                        <input type="text" class="input-text" placeholder="***" />
                    </div>
                </div>

                <button type="submit" class="btn-secondary" style="width:100%; margin-top:8px;">
                    결제하기
                </button>
            </form>

            <%
                if (payMsg != null) {
            %>
                <div class="msg <%= paySuccess ? "msg-ok" : "msg-err" %>"><%= payMsg %></div>
            <%
                }
                if (errorMsg != null) {
            %>
                <div class="msg msg-err"><%= errorMsg %></div>
            <%
                }
            %>

            <div style="margin-top:10px; display:flex; justify-content:space-between; gap:8px;">
                <a href="settings.jsp" class="btn-ghost" style="flex:1; text-align:center;">
                    설정으로 돌아가기
                </a>
                <a href="main.jsp" class="btn-ghost" style="flex:1; text-align:center;">
                    메인으로 돌아가기
                </a>
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
